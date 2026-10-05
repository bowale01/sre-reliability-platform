{{/*
Shared pod template spec, used by both the Rollout and the Deployment fallback
so the container definition stays in one place.
*/}}
{{- define "demo-service.podTemplate" -}}
metadata:
  labels:
    {{- include "demo-service.labels" . | nindent 4 }}
  annotations:
    ad.datadoghq.com/demo-service.checks: |
      {
        "openmetrics": {
          "init_config": {},
          "instances": [
            {
              "openmetrics_endpoint": "http://%%host%%:{{ .Values.service.targetPort }}/metrics",
              "namespace": "demo_service",
              "metrics": [".*"]
            }
          ]
        }
      }
    ad.datadoghq.com/demo-service.logs: |
      [{"source":"python","service":"{{ .Values.datadog.service }}"}]
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          {{- include "demo-service.selectorLabels" . | nindent 10 }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: demo-service
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
      env:
        - name: SERVICE_NAME
          value: {{ .Values.datadog.service | quote }}
        - name: FAULT_INJECTION
          value: {{ .Values.faultInjection | quote }}
        - name: LATENCY_SLOW_RATIO
          value: {{ .Values.latencySlowRatio | quote }}
        - name: LATENCY_SLOW_MS
          value: {{ .Values.latencySlowMs | quote }}
        - name: DD_ENV
          value: {{ .Values.datadog.env | quote }}
        - name: DD_SERVICE
          value: {{ .Values.datadog.service | quote }}
        - name: DD_VERSION
          value: {{ .Values.datadog.version | quote }}
        - name: DD_AGENT_HOST
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
      livenessProbe:
        httpGet:
          path: /healthz
          port: http
        initialDelaySeconds: 5
        periodSeconds: 10
        failureThreshold: 3
      readinessProbe:
        httpGet:
          path: /readyz
          port: http
        initialDelaySeconds: 3
        periodSeconds: 5
        failureThreshold: 3
      startupProbe:
        httpGet:
          path: /healthz
          port: http
        failureThreshold: 30
        periodSeconds: 2
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
{{- end -}}
