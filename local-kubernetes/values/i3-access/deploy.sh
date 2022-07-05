#!/bin/bash

function print_usage() {
  echo "You can use script by following structure:"
  echo "./deploy.sh [-argument VALUE]"
  echo "e.g."
  echo "./deploy.sh -c ldev -e \"--debug\""
  echo ""
  echo "Following arguments could be used:"
  echo " -c [value] | OPTIONAL | default=ldev  | context to be used"
  echo " -e [value] | OPTIONAL |               | extra helm args to be used while installing/upgrading (can be used multiple times)"
  echo " -v [value] | OPTIONAL | default=4.5.0 | helm chart version to be used"
}

function prepare_environment() {
  readonly HELM_CHART_NAME_I3_MOPS="i3/mops-helm"
  readonly HELM_CHART_NAME_I3_ACCESS="i3/i3-access-helm"
  readonly HELM_CHART_NAME_I3_ECHO_JWT="i3/echo-jwt-helm"

  if [[ -z "${CONTEXT}" ]]; then
    CONTEXT="ldev"
  fi

  if [[ -z ${HELM_CHART_VERSION} ]]; then
    HELM_CHART_VERSION="4.5.0"
  fi

  if [[ "${CONTEXT}" == "ldev" ]]; then
    if [[ $(which yq | wc -l) -gt 0 ]]; then
      # get default values.yaml files from i3-helm charts and temporarily store them in variable
      readonly HELM_VALUES_I3_MOPS=$(helm show values ${HELM_CHART_NAME_I3_MOPS} --version ${HELM_CHART_VERSION})
      readonly HELM_VALUES_I3_ACCESS=$(helm show values ${HELM_CHART_NAME_I3_ACCESS} --version ${HELM_CHART_VERSION})
      readonly HELM_VALUES_I3_ECHO_JWT=$(helm show values ${HELM_CHART_NAME_I3_ECHO_JWT} --version ${HELM_CHART_VERSION})

      # build image name from values.yaml files
      # e.g. registry.app.corpintra.net/i3/tex-caddy:4.5.0
      readonly MOPS_IMAGE=$(get_image_name "${HELM_VALUES_I3_MOPS}" ".mops.imageRepository" ".mops.imageTag")
      readonly I3_ACCESS_CADDY_IMAGE=$(get_image_name "${HELM_VALUES_I3_ACCESS}" ".tex-caddy-helm.image.repository" ".tex-caddy-helm.image.tag")
      readonly I3_ACCESS_TRAEFIK_IMAGE=$(get_image_name "${HELM_VALUES_I3_ACCESS}" ".tex-caddy-helm.traefik.image.repository" ".tex-caddy-helm.traefik.image.tag")
      readonly I3_ACCESS_TEX_SERVICE_IMAGE=$(get_image_name "${HELM_VALUES_I3_ACCESS}" ".tex-service-helm.image.repository" ".tex-service-helm.image.tag")
      readonly I3_ACCESS_ECHO_JWT_IMAGE=$(get_image_name "${HELM_VALUES_I3_ECHO_JWT}" ".image.repository" ".image.tag")

      echo "Pulling images:"
      pull_docker_images
      echo "Loading images into kind cluster:"
      load_docker_images_into_kind
    else
      echo "yq is not installed on your system yet, you could speed up i3-access deployment by installing it:"
      echo "https://github.com/mikefarah/yq#install"
      echo ""
      echo "By installing 'yq' all i3-access docker images will be loaded onto your host system on first deployment"
      echo "and be loaded into kind cluster everytime deploying i3-access. Image pulling time could be decreased"
      echo "by this step enormously."
      echo ""
    fi
  fi
}

# $1: helm repository
# $2: image repository
# $3: image tag
function get_image_name() {
  echo "$(echo "${1}" | yq "${2}"):$(echo "${1}" | yq "${3}")"
}

function pull_docker_images() {
  pull_docker_image "${MOPS_IMAGE}"
  pull_docker_image "${I3_ACCESS_CADDY_IMAGE}"
  pull_docker_image "${I3_ACCESS_TRAEFIK_IMAGE}"
  pull_docker_image "${I3_ACCESS_TEX_SERVICE_IMAGE}"
  pull_docker_image "${I3_ACCESS_ECHO_JWT_IMAGE}"
}

# $1: docker image
function pull_docker_image() {
  # check if docker image ($1) already exists on host machine
  if [[ $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -c "${1}") -lt 1 ]]; then
    # get registry url to check if docker is authenticated against this registry.
    # cut command splits docker image name with delimiter (-d "/") into several parts and return
    # the only necessary first part (-f1)
    # e.g.
    #   registry.app.corpintra.net/i3/tex-caddy:4.5.0
    #   1 | registry.app.corpintra.net       <---- this part is necessary
    #   2 | i3
    #   3 | tex-caddy:4.5.0
    DOCKER_REGISTRY_URL=$(cut -d "/" -f1 <<<"${1}")
    if [[ $(grep -c "${DOCKER_REGISTRY_URL}" ~/.docker/config.json) -eq 0 ]]; then
      echo "You are not authenticated against ${DOCKER_REGISTRY_URL}, pulling image may fail"
    fi
    docker pull "${1}"
  else
    echo "Image '${1}' already present on host, pulling skipped"
  fi
}

function load_docker_images_into_kind() {
  load_docker_image_into_kind "${MOPS_IMAGE}"
  load_docker_image_into_kind "${I3_ACCESS_CADDY_IMAGE}"
  load_docker_image_into_kind "${I3_ACCESS_TRAEFIK_IMAGE}"
  load_docker_image_into_kind "${I3_ACCESS_TEX_SERVICE_IMAGE}"
  load_docker_image_into_kind "${I3_ACCESS_ECHO_JWT_IMAGE}"
}

function load_docker_image_into_kind() {
  kind load docker-image "${1}" --name "${CONTEXT}"
}

function deploy_preconditions() {
  # on 'ldev' stage it is necessary to connect to services running on host machine (e.g. ms in IntelliJ)
  # therefore it is necessary to deploy special pod (dockerhost) in cluster to provide access to
  # services running on development machine
  # further information could be found here:
  #   https://github.com/kubernetes-sigs/kind/issues/1200
  #   https://github.com/kubernetes-sigs/kind/issues/1200#issuecomment-568735188
  #   https://github.com/qoomon/docker-host
  if [[ ${CONTEXT} == "ldev" ]]; then
    # depending on operating system it is necessary to deploy separate configuration
    # MacOS:          deployment-dockerhost-macos.yaml
    # Linux/Windows:  deployment-dockerhost.yaml
    if [[ ${OSTYPE} == "darwin"* ]]; then
      kubectl apply -f ./deployment-dockerhost-macos.yaml
    else
      kubectl apply -f ./deployment-dockerhost.yaml
    fi

    # apply kubernetes services responsible for redirection to services running on development machine
    find . -maxdepth 1 -regex ".*service-.*-${CONTEXT}.yaml" \
      -exec kubectl apply -f {} \;
  fi
}

function deploy() {
  if [[ ${CONTEXT} == "ldev" ]] || [[ ${CONTEXT} == "dev" ]]; then
    # on ldev and dev install mock services beside i3-access
    # deploy i3-access
    helm upgrade --install i3-access ${HELM_CHART_NAME_I3_ACCESS} \
      -f "i3-access/values-${CONTEXT}.yaml" \
      -f "i3-access/mock-op-values-${CONTEXT}.yaml" \
      --render-subchart-notes \
      --version ${HELM_CHART_VERSION} ${EXTRA_HELM_ARGS}

    # deploy mops
    helm upgrade --install mops ${HELM_CHART_NAME_I3_MOPS} \
      -f "mops/values-${CONTEXT}.yaml" \
      --version ${HELM_CHART_VERSION} ${EXTRA_HELM_ARGS}

    # deploy
    helm upgrade --install echo-jwt ${HELM_CHART_NAME_I3_ECHO_JWT} \
      -f "echo-jwt/values-${CONTEXT}.yaml" \
      --version ${HELM_CHART_VERSION} ${EXTRA_HELM_ARGS}
  else
    # for any other stage than 'ldev' and 'dev' only deploy i3-access:
    # deploy i3-access
    helm upgrade --install i3-access ${HELM_CHART_NAME_I3_ACCESS} \
      -f "i3-access/values-${CONTEXT}.yaml" \
      --render-subchart-notes \
      --version ${HELM_CHART_VERSION} ${EXTRA_HELM_ARGS}
  fi
}

while getopts "c:e:v:" arg; do
  case "${arg}" in
  c)
    CONTEXT=${OPTARG}
    ;;
  e)
    EXTRA_HELM_ARGS+="${OPTARG} "
    ;;
  v)
    HELM_CHART_VERSION=${OPTARG}
    ;;
  *)
    print_usage
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

prepare_environment
deploy_preconditions
deploy
