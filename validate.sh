#!/usr/bin/env bash

FILE=$1
NAMESPACE=$2

[ -z $FILE ] && echo "No deployment.yaml specified" && exit 1
[ -z $NAMESPACE ] && echo "No namespace specified" && exit 1


NAMESPACE_STRUCT=$(grep -E '^.*(kind|metadata|  namespace):' $1)
echo "$NAMESPACE_STRUCT" | while read line ; do

  if [[ "$metadata" = true ]]; then
    if [[ "$line" == *"namespace"* ]]; then
      if [ $(echo "$line" | awk '{ print $2 }') != "$NAMESPACE" ]; then
        echo "Namespace Validation Failed. Namespace should be: $2 but $line was found." && exit 1
      fi
      unset metadata
      continue
    else
       echo "Namespace Validation Failed. Missing 'namespace:' field following a 'metadata' field." && exit 1
    fi
  fi

  if [[ "$kind" = true ]]; then
    if [[ "$line" == *"metadata:"* ]]; then
      unset kind
      metadata=true
      continue
    else
    echo "Metadata Validation Failed. Missing 'metadata' field following a 'kind' field." && exit 1
    fi
  fi

  if [[ "$line" == *"kind:"* ]]; then
    kind=true
    continue
  fi

done

INGRESS_TEST=$(grep "kind: Ingress" $1)
[[ ! -z "$INGRESS_TEST" ]] && echo "Ingress Validation Failed. Do NOT include ingress rules in deployment yamls!" && exit 1

NAMESPACE_TEST=$(grep "kind: Namespace" $1)
[[ ! -z "$NAMESPACE_TEST" ]] && echo "Namespace Test Validation Failed. Do NOT include Namespace creation in deployment yamls!" && exit 1
