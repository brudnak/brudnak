```shell
#!/bin/bash

BINARY_URL="https://github.com/brudnak/vai-vacuum/releases/download/v1.0.0-beta/vai-vacuum"

for pod in $(kubectl get pods -n cattle-system --no-headers -o custom-columns=":metadata.name" | grep "^rancher-" | grep -v "^rancher-webhook"); do
    echo "Processing pod: $pod"
    
    # Download and run vai-vacuum directly in the pod
    kubectl exec $pod -n cattle-system -c rancher -- sh -c \
        "curl -kL -o /tmp/vai-vacuum '$BINARY_URL' && chmod +x /tmp/vai-vacuum && /tmp/vai-vacuum && rm /tmp/vai-vacuum" \
        | base64 -d > ${pod}-snapshot.db
    
    echo "Snapshot saved to ${pod}-snapshot.db"
done
```

<img src="gh-dark-mode-only">
  [![Apple Music GitHub profile](https://music-profile.rayriffy.com/theme/light.svg?uid=000785.fee0d6c827a34238bd30098893b45df7.2205#gh-light-mode-only)](https://music-profile.rayriffy.com)

</img>
<p align="center">
  [![Apple Music GitHub profile](https://music-profile.rayriffy.com/theme/dark.svg?uid=000785.fee0d6c827a34238bd30098893b45df7.2205)](https://music-profile.rayriffy.com)
</p>


<img src="https://github.com/brudnak/brudnak/blob/main/img/online.gif" alt="" width="140">

## 🌃 GitHub Skyline 
![Auto Updated](https://img.shields.io/badge/Generated%20by-GitHub%20Actions-blue?logo=githubactions)

<p align="center">
  <img src="./skyline-dark.png#gh-dark-mode-only" />
</p>
<p align="center">
  <img src="./skyline-light.png#gh-light-mode-only" />
</p>

<p align="center">
  <a href="./skyline-full.stl">🔗 View 3D STL Model on GitHub</a>
</p>

<!-- log tracker start -->

## 🗺️ Global Commits
![Auto Updated](https://img.shields.io/badge/Generated%20by-GitHub%20Actions-blue?logo=githubactions)

| Country         | Region / State | City           | Sessions |
| --------------- | -------------- | -------------- | -------- |
| 🇨🇦 Canada        | Quebec         | L'Ange-Gardien | 1        |
| 🇨🇦 Canada        | Quebec         | Québec         | 3        |
| 🇺🇸 United States | Arizona        | Phoenix        | 1        |
| 🇺🇸 United States | Florida        | Jacksonville   | 1        |
| 🇺🇸 United States | Florida        | Orlando        | 1        |
| 🇺🇸 United States | Indiana        | Plainfield     | 1        |
| 🇺🇸 United States | New York       | Niagara Falls  | 2        |
| 🇺🇸 United States | Oklahoma       | Oklahoma City  | 1        |
| 🇺🇸 United States | Texas          | Fort Stockton  | 1        |
| 🇺🇸 United States | Virginia       | Purcellville   | 1        |

<!-- log tracker end -->
<hr>

<!-- Where to find these icons: https://simpleicons.org -->
<p align="center">
  <img src="https://img.shields.io/badge/-Go-00ADD8?logo=go&logoColor=white&style=fla" />
  <img src="https://img.shields.io/badge/-Kubernetes-326CE5?logo=kubernetes&logoColor=white&style=flat" />
  <img src="https://img.shields.io/badge/-Rancher-0075A8?logo=rancher&logoColor=white&style=flat" />
  <img src="https://img.shields.io/badge/-Terraform-7B42BC?logo=terraform&logoColor=white&style=flat" />
  <img src="https://img.shields.io/badge/-AWS-232F3E?logo=amazonwebservices&logoColor=white&style=flat" />
  <img src="https://img.shields.io/badge/-JavaScript-F7DF1E?logo=javascript&logoColor=white&style=flat" />
  <img src="https://img.shields.io/badge/-HTML5-E34F26?logo=html5&logoColor=white&style=flat" />
  <img src="https://img.shields.io/badge/-CSS3-1572B6?logo=css3&logoColor=white&style=flat" />
</p>


<p align="center">
  <a href="https://gitlab.com/brudnak">
    <img src="https://img.shields.io/badge/-GitLab-FC6D26?logo=gitlab&logoColor=white&style=flat" />
  </a>
  <a href="https://hub.docker.com/u/brudnak">
    <img src="https://img.shields.io/badge/-Docker_Hub-2496ED?logo=docker&logoColor=white&style=flat" />
  </a>
  <a href="https://bitbucket.org/brudnak">
    <img src="https://img.shields.io/badge/-Bitbucket-0052CC?logo=bitbucket&logoColor=white&style=flat" />
  </a>
</p>
