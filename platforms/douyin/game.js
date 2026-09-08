// 抖音上屏画布的唯一尺寸入口；导出器将本文件复制为小游戏 game.js。
// Canvas Resize Policy 必须为 0，避免 SDK 虚拟 window 再次改写真实宿主尺寸。

function positive(value) {
    return typeof value === 'number' && Number.isFinite(value) && value > 0;
}

function windowSize(info) {
    return info && positive(info.windowWidth) && positive(info.windowHeight)
        ? { width: info.windowWidth, height: info.windowHeight } : null;
}

// 宿主边界只接收成对的有效尺寸；安全区由 Godot UI 单独避让，不从画布扣除。
function readMetrics(host, event) {
    const system = host.getSystemInfoSync();
    const windowInfo = typeof host.getWindowInfo === 'function' ? host.getWindowInfo() : null;
    const size = windowSize(event && (event.size || event)) || windowSize(windowInfo)
        || windowSize(system) || (positive(system.screenWidth) && positive(system.screenHeight)
            ? { width: system.screenWidth, height: system.screenHeight } : null);
    const ratio = windowInfo && positive(windowInfo.pixelRatio) ? windowInfo.pixelRatio : system.pixelRatio;
    if (!size || !positive(ratio)) throw new Error('DOUYIN VIEWPORT: invalid host dimensions or pixel ratio');
    return { ...size, ratio };
}

const TOUCH_EVENTS = new Set(['touchstart', 'touchmove', 'touchend', 'touchcancel']);

function touchPoint(point) {
    const x = Number.isFinite(point && point.clientX) ? point.clientX
        : Number.isFinite(point && point.screenX) ? point.screenX : point && point.x;
    const y = Number.isFinite(point && point.clientY) ? point.clientY
        : Number.isFinite(point && point.screenY) ? point.screenY : point && point.y;
    if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
    const identifier = Number.isFinite(point && point.identifier) ? point.identifier : 0;
    return { ...point, identifier, clientX: x, clientY: y, screenX: x, screenY: y, pageX: x, pageY: y };
}

// 小游戏没有浏览器 DOM；将官方 tt 触摸事件适配为 Godot Web 监听的 Canvas 事件。
function installTouchBridge(host, canvas, bind) {
    const listeners = new Map(Array.from(TOUCH_EVENTS, type => [type, new Set()]));
    const nativeAdd = typeof canvas.addEventListener === 'function' ? canvas.addEventListener.bind(canvas) : null;
    const nativeRemove = typeof canvas.removeEventListener === 'function' ? canvas.removeEventListener.bind(canvas) : null;
    canvas.addEventListener = (type, listener, options) => {
        if (TOUCH_EVENTS.has(type)) listeners.get(type).add(listener);
        else if (nativeAdd) nativeAdd(type, listener, options);
    };
    canvas.removeEventListener = (type, listener, options) => {
        if (TOUCH_EVENTS.has(type)) listeners.get(type).delete(listener);
        else if (nativeRemove) nativeRemove(type, listener, options);
    };
    const dispatch = type => source => {
        const touches = Array.from(source && source.touches || []).map(touchPoint).filter(Boolean);
        const changedTouches = Array.from(source && source.changedTouches || source && source.touches || []).map(touchPoint).filter(Boolean);
        const event = {
            type, touches, changedTouches, target: canvas, currentTarget: canvas,
            timeStamp: Number.isFinite(source && source.timeStamp) ? source.timeStamp : Date.now(),
            cancelable: true, defaultPrevented: false,
            preventDefault() { this.defaultPrevented = true; },
            stopPropagation() {},
        };
        for (const listener of listeners.get(type)) {
            if (typeof listener === 'function') listener(event);
            else if (listener && typeof listener.handleEvent === 'function') listener.handleEvent(event);
        }
    };
    bind('onTouchStart', 'offTouchStart', dispatch('touchstart'));
    bind('onTouchMove', 'offTouchMove', dispatch('touchmove'));
    bind('onTouchEnd', 'offTouchEnd', dispatch('touchend'));
    bind('onTouchCancel', 'offTouchCancel', dispatch('touchcancel'));
    return () => { for (const set of listeners.values()) set.clear(); };
}

// 只创建一个上屏 canvas；监听随小游戏进程存活，不随 Home/Adventure 页面重建。
function createViewport(host) {
    let metrics = readMetrics(host);
    const canvas = host.createCanvas();
    const bindings = [];
    let disposed = false;
    let clearTouchBridge = () => {};
    canvas.style = canvas.style || {};

    // SDK 只在启动时补一次 DOM 尺寸；输入矩形必须读取当前宿主逻辑像素。
    canvas.getBoundingClientRect = () => ({
        x: 0, y: 0, left: 0, top: 0,
        right: metrics.width, bottom: metrics.height,
        width: metrics.width, height: metrics.height,
    });

    function applySize() {
        const width = Math.round(metrics.width * metrics.ratio);
        const height = Math.round(metrics.height * metrics.ratio);
        // 重复写 width/height 会重置渲染缓冲，尺寸不变时不得重写。
        if (canvas.width !== width) canvas.width = width;
        if (canvas.height !== height) canvas.height = height;
        canvas.clientWidth = metrics.width;
        canvas.clientHeight = metrics.height;
        canvas.style.width = metrics.width + 'px';
        canvas.style.height = metrics.height + 'px';
    }

    function refresh(event) {
        if (disposed) return;
        try {
            // 后台临时零尺寸不能破坏上一份可用画布。
            if (event && (event.size || 'windowWidth' in event || 'windowHeight' in event)
                && !windowSize(event.size || event)) return;
            metrics = readMetrics(host, event);
            applySize();
        } catch (error) {
            console.error('DOUYIN VIEWPORT: resize ignored', error);
        }
    }

    function bind(on, off, callback) {
        if (typeof host[on] !== 'function' || typeof host[off] !== 'function') return;
        host[on](callback);
        bindings.push({ off, callback });
    }

    function dispose() {
        if (disposed) return;
        disposed = true;
        for (const { off, callback } of bindings) host[off](callback);
        bindings.length = 0;
        clearTouchBridge();
    }

    applySize();
    clearTouchBridge = installTouchBridge(host, canvas, bind);
    bind('onWindowResize', 'offWindowResize', refresh);
    bind('onShow', 'offShow', () => refresh());
    return { canvas, refresh, dispose };
}

// 按数值比较基础库版本，3.100 不能按字符串误判为低于 3.95。
function supportsPlugin(version) {
    if (typeof version !== 'string' || !/^\d+\.\d+\.\d+(?:\.\d+)?$/.test(version)) return false;
    const parts = version.split('.').map(Number);
    const minimum = [3, 95, 0];
    for (let i = 0; i < minimum.length; i++) {
        if (parts[i] !== minimum[i]) return parts[i] > minimum[i];
    }
    return true;
}

async function main() {
    let viewport;
    try {
        const config = require('./godot.config.js');
        if (config.canvasResizePolicy !== 0) throw new Error('DOUYIN VIEWPORT: canvasResizePolicy must be 0');
        // 先占有唯一上屏画布，再加载可能创建离屏画布的 SDK。
        viewport = createViewport(tt);
        const sdkVersion = tt.getSystemInfoSync().SDKVersion;
        const plugin = supportsPlugin(sdkVersion);
        const launcher = plugin ? requirePlugin('GodotPlugin/index.js') : require('./godot.launcher.js');
        console.log('DOUYIN VIEWPORT:', plugin ? 'plugin' : 'embedded', sdkVersion,
            viewport.canvas.width, viewport.canvas.height);
        const onExit = config.onExit;
        await launcher.start({
            canvas: viewport.canvas,
            config: { ...config, onExit: code => {
                viewport.dispose();
                if (typeof onExit === 'function') onExit(code);
            } },
        });
        // 启动期间可能切换机型；完成时同步 SDK 一次性补入的 clientWidth/Height。
        viewport.refresh();
    } catch (error) {
        if (viewport) viewport.dispose();
        console.error('DOUYIN START FAILED:', error);
    }
}

main();

/* SDK 扫描保留：tt.navigateToScene */
