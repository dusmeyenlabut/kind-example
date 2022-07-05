#!/bin/bash

function print_usage() {
  echo "You can use script by following structure:"
  echo "./delete.sh [-argument VALUE]"
  echo "e.g."
  echo "./delete.sh -c ldev"
  echo ""
  echo "Following arguments could be used:"
  echo " -c [value] | OPTIONAL | default=ldev | context to be used"
  exit 1
}

function check_preconditions() {
  if [[ -z "${CONTEXT}" ]]; then
    CONTEXT=ldev
  fi

  read -r -n 1 -p "Do you really want to delete i3-access components on context '${CONTEXT}'? [y|n] (default: n) " DELETE
  echo ""

  if [[ ${DELETE} != "y" ]]; then
    echo "deletion of i3-access components aborted"
    exit 1
  fi

  readonly CURRENT_CONTEXT=$(kubectl config current-context)
  if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]] && [[ "${CURRENT_CONTEXT}" != "kind-${CONTEXT}" ]]; then
    echo "current context '${CURRENT_CONTEXT}' and provided context '${CONTEXT}', deletion of i3-access components aborted"
    exit 1
  fi
}

function delete() {
  helm un echo-jwt
  helm un mops
  helm un i3-access
}

function delete_preconditions() {
  if [[ ${CONTEXT} == "ldev" ]]; then
    # depending on operating system separate configuration is deployed
    if [[ ${OSTYPE} == "darwin" ]]; then
      kubectl delete -f ./deployment-dockerhost-macos.yaml
    else
      kubectl delete -f ./deployment-dockerhost.yaml
    fi

    find . -maxdepth 1 -regex ".*service-.*-${CONTEXT}.yaml" \
      -exec kubectl delete -f {} \;
  fi
}

while getopts "c:" arg; do
  case "${arg}" in
  c)
    CONTEXT=${OPTARG}
    ;;
  *)
    print_usage
    ;;
  esac
done
shift $((OPTIND - 1))

check_preconditions
delete
delete_preconditions