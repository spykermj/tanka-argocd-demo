{
  // Plugin specific configs
  local tankaVersion = '0.24.0',
  local jsonnetBundlerVersion = 'v0.5.1',
  local pluginDir = '/home/argocd/cmp-server/plugins',

  argoCdChart: {
    helmApplication: {
      apiVersion: 'argoproj.io/v1alpha1',
      kind: 'Application',
      metadata: {
        name: 'argo-cd',
        namespace: 'argocd',
      },
      spec: {
        project: 'default',
        destination: {
          namespace: 'argocd',
          server: 'https://kubernetes.default.svc',
        },
        source: {
          chart: 'argo-cd',
          repoURL: 'https://argoproj.github.io/argo-helm',
          targetRevision: '5.27.3',
          helm: {
            releaseName: 'argo-cd',
            values: |||
              %s
            ||| % std.manifestYamlDoc(
              {
                configs: {
                  params: {
                    'server.insecure': true,
                    'server.disable.auth': true,
                  },
                },
                repoServer: {
                  extraContainers: [
                    {
                      name: 'cmp',
                      image: 'grafana/tanka:%s' % tankaVersion,

                      command: [
                        'sh',
                        '-c',
                        '/var/run/argocd/argocd-cmp-server',
                      ],
                      securityContext: {
                        runAsNonRoot: true,
                        runAsUser: 999,
                      },
                      volumeMounts: [
                        {
                          mountPath: '/var/run/argocd',
                          name: 'var-files',
                        },
                        {
                          mountPath: pluginDir,
                          name: 'plugins',
                        },
                        {
                          mountPath: '/home/argocd/cmp-server/config/plugin.yaml',
                          subPath: 'plugin.yaml',
                          name: 'cmp-plugin',
                        },
                      ],
                    },
                  ],
                  volumes: [
                    {
                      configMap: {
                        name: 'cmp-plugin',
                      },
                      name: 'cmp-plugin',
                    },
                    {
                      emptyDir: {},
                      name: 'cmp-tmp',
                    },
                  ],
                },
              }
            ),
          },
        },
      },
    },
  },

  argoCdPlugin: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'cmp-plugin',
      namespace: 'argocd',
    },
    data: {
      'plugin.yaml': |||
        %s
      ||| % std.manifestYamlDoc({
        apiVersion: 'argoproj.io/v1alpha1',
        kind: 'ConfigManagementPlugin',
        metadata: {
          name: 'tanka',
          namespace: 'argocd',
        },
        spec: {
          version: tankaVersion,
          init: {
            command: [
              'sh',
              '-c',
              'jb install',
            ],
          },
          generate: {
            command: [
              'sh',
              '-c',
              'tk show environments/${ARGOCD_ENV_TK_ENV} --dangerous-allow-redirect',
            ],
          },
          discover: {
            fileName: '*',
          },
        },
      }),
    },
  },

  defaultApplication: {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'Application',
    metadata: {
      name: 'default',
    },
    spec: {
      project: 'default',
      source: {
        repoURL: 'https://github.com/spykermj/tanka-argocd-demo',
        path: 'tanka',
        targetRevision: 'change_to_fork',
        plugin: {
          env: [
            {
              name: 'TK_ENV',
              value: 'default',
            },
          ],
        },
      },
      destination: {
        server: 'https://kubernetes.default.svc',
      },
      syncPolicy: {
        automated: {
          prune: true,
          selfHeal: true,
        },
      },
    },
  },

  defaultProject: {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'AppProject',
    metadata: {
      name: 'default',
      namespace: 'argocd',
      finalizers: [
        'resources-finalizer.argocd.argoproj.io',
      ],
    },
    spec: {
      description: 'MyOrg Default AppProject',
      sourceRepos: [
        '*',
      ],
      clusterResourceWhitelist: [
        {
          group: '*',
          kind: '*',
        },
      ],
      destinations: [
        {
          namespace: '*',
          server: '*',
        },
      ],
    },
  },
}
