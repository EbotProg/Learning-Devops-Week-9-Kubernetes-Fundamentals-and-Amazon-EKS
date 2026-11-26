{{/* Labels put on every object (helps `kubectl get all -l app.kubernetes.io/instance=crud`) */}}
{{- define "crud.labels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
