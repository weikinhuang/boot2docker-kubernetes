#!/usr/bin/env bash
set -euo pipefail

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: k8s-worker
  namespace: workers
  labels:
    app: k8s-worker
spec:
  replicas: 0
  selector:
    matchLabels:
      app: k8s-worker
  template:
    metadata:
      labels:
        app: k8s-worker
    spec:
      containers:
      - name: k8s-worker
        image: docker:latest
        command:
        - /usr/bin/worker-script.sh
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: COMPOSE_DIR
          value: "$(dirname "$(self-container-info.sh  | jq -r '.[0].Mounts | map(select(.Destination == "/data")) | .[0].Source')")"
        - name: NODE_TYPE
          value: node
        volumeMounts:
        - mountPath: /mnt/share/data/kubeconfig.node
          name: mnt-share-data-kubeconfig-node
          readOnly: true
        - mountPath: /usr/bin/kubectl
          name: usr-local-bin-kubectl
          readOnly: true
        - mountPath: /var/run/docker.sock
          name: mnt-host-docker
        - name: k8s-worker-script
          mountPath: /usr/bin/worker-script.sh
          subPath: worker-script.sh
        - name: k8s-worker-script
          mountPath: /usr/bin/automate-scale.sh
          subPath: automate-scale.sh
        - name: k8s-worker-script
          mountPath: /usr/bin/kubectl-sa
          subPath: kubectl-sa
        lifecycle:
          preStop:
            exec:
              command:
                - /usr/bin/automate-scale.sh
      terminationGracePeriodSeconds: 15
      nodeSelector:
        node-role.kubernetes.io/master: ""
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      volumes:
      - name: mnt-share-data-kubeconfig-node
        hostPath:
          path: /mnt/share/data/kubeconfig.node
      - name: mnt-host-docker
        hostPath:
          path: /mnt/HOST_DOCKER.sock
      - name: usr-local-bin-kubectl
        hostPath:
          path: /usr/local/bin/kubectl
      - name: k8s-worker-script
        configMap:
          name: k8s-worker-script
          items:
          - key: worker-script.sh
            path: worker-script.sh
            mode: 0755
          - key: automate-scale.sh
            path: automate-scale.sh
            mode: 0755
          - key: kubectl-sa
            path: kubectl-sa
            mode: 0755
EOF
