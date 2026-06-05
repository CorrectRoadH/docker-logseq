FROM ghcr.io/linuxserver/baseimage-kasmvnc:ubuntunoble

ENV TITLE=Logseq

ENV DEBIAN_FRONTEND=noninteractive

# 安装必要的包
RUN apt-get update && \
    apt-get install -y \
        # packaging support
        wget \
        python3-xdg \
        curl \
        apt-utils \
        ca-certificates \
        fonts-noto-cjk \
        fonts-noto-cjk-extra \
        # 音频相关
        libasound2t64 \
        # GTK 相关
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libcups2 \
        libdrm2 \
        libgtk-3-0 \
        libgbm1 \
        # X11 相关
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxrandr2 \
        libxshmfence1 \
        libx11-xcb1 \
        libxcursor1 \
        libxi6 \
        libxtst6 \
        && \
        # 清理缓存
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* && \
        :

# Fetch latest Logseq release dynamically at build time
RUN LOGSEQ_VERSION=$(curl -s https://api.github.com/repos/logseq/logseq/releases/latest | \
      python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])") && \
    echo "Installing Logseq ${LOGSEQ_VERSION}" && \
    curl -L "https://github.com/logseq/logseq/releases/download/${LOGSEQ_VERSION}/Logseq-linux-x64-${LOGSEQ_VERSION}.AppImage" \
      -o /usr/local/bin/logseq && \
    chmod +x /usr/local/bin/logseq && \
    cd /usr/local/bin && \
    ./logseq --appimage-extract && \
    chmod -R 755 squashfs-root && \
    ln -s /usr/local/bin/squashfs-root/Logseq /usr/local/bin/Logseq && \
    rm /usr/local/bin/logseq

# Bake in workbench graph auto-open patch to preload.js
RUN PRELOAD="/usr/local/bin/squashfs-root/resources/app/js/preload.js" && \
    cat >> "${PRELOAD}" << 'PATCH'

// Auto-open graph on startup.
// Expose __MOCKED_OPEN_DIR_PATH__ in renderer world via contextBridge
contextBridge.exposeInMainWorld('__MOCKED_OPEN_DIR_PATH__', '/config/logseq-graph')

// After DOM ready, inject renderer-world script to auto-click Add Graph button
window.addEventListener('DOMContentLoaded', function () {
  // We build the code string piece-by-piece to avoid string escaping hell
  var graphPath = '/config/logseq-graph'
  var code = '(function autoOpenGraph(){' +
    'var G="' + graphPath + '";' +
    'window.__MOCKED_OPEN_DIR_PATH__=G;' +
    'function tryClick(n){' +
    'if(n<=0)return;' +
    'var btns=document.querySelectorAll(".add-graph-btn");' +
    'for(var i=0;i<btns.length;i++){btns[i].click();return;}' +
    'var ss=document.querySelectorAll("strong");' +
    'for(var j=0;j<ss.length;j++){' +
    'if(ss[j].textContent.indexOf("Choose a folder")!==-1){ss[j].click();return;}' +
    '}' +
    'setTimeout(function(){tryClick(n-1);},1000);' +
    '}' +
    'setTimeout(function(){tryClick(15);},3000);' +
    '})();'
  webFrame.executeJavaScript(code).catch(function (err) {
    console.warn('[logseq-auto-open] error:', err)
  })
})
PATCH

COPY /root /

EXPOSE 3000

VOLUME /config
