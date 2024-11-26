# Why the Project
Deploy Logseq in  any headless server, like aws、aliyun、tencent、huawei and so on.  now we can have a stable api http server to call logseq.

# Usage
```
docker run -d \
  --privileged \
  -p 3000:3000 \  
  -p 12315:12315 \
  -v config:/config \
  -v notes:/notes \
  --name logseq \
  correctroad/logseq:v0.10.9
```