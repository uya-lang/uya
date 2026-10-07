# std.image —— 图片位图与 JPEG 编解码

> **状态**：基线 JPEG（Huffman + 8x8 DCT）解码与编码已可用；渐进式/算术编码等
> 明确拒绝（见下面的支持矩阵）。
> **模块路径**：`use std.image.jpeg_decode.jpeg_decode;` 等（见各节）。
> **零依赖**：纯 Uya，不用 libm（全整数定点），编码不一定需要堆。

---

## 1. 为什么有这一层

多模态模型要的是**内联 base64**，而调用方手里往往是「一坨字节」。中间要有人回答：

1. 这是不是图片、是哪种（决定 MIME）？
2. 它多大（宽高）？
3. 装得下吗（像素/字节预算）？
4. 超预算了能不能**缩一缩**再发？

前三个问题靠**读文件头**就能回答；第四个问题需要**编解码器** —— 这正是本模块补上的。
在此之前，超预算的图只有「接受原图」或「明确拒绝」两条路。

## 2. 分层

| 文件 | 职责 | 有没有堆 |
|---|---|---|
| `image.uya` | 内存位图 `Image`（灰度/RGB、行优先）与像素读写 | 调用方给分配器 |
| `jpeg_tables.uya` | Annex K 量化表 + 标准 Huffman 表 + 质量缩放 + 码表装配 | **无** |
| `jpeg_bits.uya` | 熵段的位读写（0xFF00 反转义、RSTn、补 1 收尾） | **无** |
| `jpeg_dct.uya` | 8x8 整数 FDCT / IDCT / 量化 / 反量化 | **无** |
| `jpeg_marker.uya` | 段解析（SOI/APPn/DQT/DHT/DRI/SOF/SOS/EOI） | **无** |
| `jpeg_decode.uya` | 解码主流程（Huffman → 反量化 → IDCT → 上采样 → RGB） | 平面 + 输出图 |
| `jpeg_encode.uya` | 编码主流程（RGB→YCbCr → 下采样 → FDCT → 量化 → Huffman → 写段） | 无（复用栈缓冲） |

分层的判据是**「能不能单独测」**：`jpeg_dct` 可以只喂一块系数、
`jpeg_bits` 可以只喂几字节、`jpeg_tables` 可以只查表 —— 都不需要一张真图。

## 3. 支持矩阵

| 特性 | 解码 | 编码 | 说明 |
|---|---|---|---|
| 基线顺序 DCT（SOF0 / SOF1） | ✅ | ✅（写 SOF0） | |
| 灰度（1 分量） | ✅ | ✅ | 输出 `IMAGE_GRAY` |
| YCbCr 三分量 | ✅ | ✅ | 输出 `IMAGE_RGB` |
| 4:4:4 / 4:2:2 / 4:2:0 | ✅ | ✅ | 编码用 `subsample` 选 |
| 任意 h/v ∈ 1..4 的矩形采样 | ✅ | ➖ | 解码支持（块重复上采样） |
| DRI 重启间隔（RSTn） | ✅ | ➖（不写 DRI） | |
| 8-bit 精度 | ✅ | ✅ | 12-bit 拒绝 |
| 渐进式（SOF2） | ❌ `JpegUnsupported` | ➖ | 见 §6 |
| 算术编码（SOF9/10、DAC） | ❌ `JpegUnsupported` | ➖ | |
| 无损（SOF3） | ❌ `JpegUnsupported` | ➖ | |
| 4 分量（CMYK/YCCK） | ❌ `JpegUnsupported` | ➖ | |
| EXIF 方向 / ICC / 缩略图 | ➖（跳过，不影响像素） | ➖ | |

> **上采样用「块重复」**：每个色度样本复制到它覆盖的 h×v 个像素上。这与
> `djpeg -nosmooth` 一致；三角滤波（`djpeg` 默认）更平滑，但对「缩图 → 重编码」
> 的用途收益看不出来，而实现只有几行。

## 4. 解码

```uya
use std.image.jpeg_decode.jpeg_decode;
use std.image.jpeg_decode.jpeg_decode_info;
use std.image.jpeg_decode.JpegInfo;
use std.image.jpeg_decode.jpeg_info_blank;
use std.image.image.image_free;
use std.mem.allocator.get_allocator;
use std.mem.allocator.MallocAllocator;

const alc: MallocAllocator = get_allocator()[0];

// ① 先问尺寸（不解码、不分配堆）：适合「决定收不收」的关卡
var info: JpegInfo = jpeg_info_blank();
_ = try jpeg_decode_info(data, n, &info);
// info.width / info.height / info.ncomp / info.progressive

// ② 真解一张图
var img: Image = Image{ width: 0, height: 0, channels: 0,
    pixels: null, allocator: null };
_ = try jpeg_decode(data, n, alc, &img);
defer { image_free(&img); };
// img.channels == IMAGE_GRAY(1) 或 IMAGE_RGB(3)
```

* `jpeg_decode_info` **在渐进式上也工作**（`progressive = true` 且宽高有效）——
  「先问尺寸」的用途要能在拒绝之前就说清「4032x3024 的渐进式 JPEG 我解不了」。
* `jpeg_decode` 成功时 `img` 里是新缓冲；**失败时 `img` 已被清成空图**，
  调用方不必（也不该）再 `image_free`。

## 5. 编码

```uya
use std.image.jpeg_encode.jpeg_encode;
use std.image.jpeg_encode.jpeg_encode_q;
use std.image.jpeg_encode.jpeg_options_default;
use std.image.jpeg_encode.JpegEncodeOptions;
use std.image.jpeg_encode.jpeg_max_bytes;

// ① 准备缓冲：必须先按上界分配（否则报 JpegBufferTooSmall）
const cap: usize = jpeg_max_bytes(img.width, img.height);
const buf: &u8 = try alc.alloc(cap);
defer { alc.dealloc(buf as &byte); };
var out_len: usize = 0;

// ② 编（缺省 = 质量 85、4:2:0）
var opts: JpegEncodeOptions = jpeg_options_default();
opts.quality = 80;
opts.subsample = JPEG_SUB_420;   // 或 JPEG_SUB_422 / JPEG_SUB_444
_ = try jpeg_encode(&img, &opts, buf, cap, alc, &out_len);

// 简写：只调质量
_ = try jpeg_encode_q(&img, 80, buf, cap, alc, &out_len);
```

* 输出是 **JFIF**（APP0）+ 标准 Annex K 量化表/Huffman 表（不做码表优化）。
* `quality` 1..100：`<50` 时 `scale = 5000/q`、否则 `scale = 200-2q`，
  与 libjpeg/T.81 K.4 同款；表值夹在 1..255。
* `subsample` 只对 RGB 有意义；灰度恒 1x1。非法值回退 4:2:0。

### 质量与体积（32x32 渐变+高频，本库自解往返）

| quality | 采样 | 字节数 | 平均绝对误差 |
|---|---|---|---|
| 20 | 4:2:0 | 663 | 8/255 |
| 90 | 4:2:0 | 887 | 4/255 |
| 95 | 4:2:0 | 1024 | 3/255 |
| 90 | 4:4:4 | 1100 | 2/255 |
| 100 | 4:4:4 | 2042 | 1/255 |

## 6. 错误

| 错误 | 什么时候 | 怎么处理 |
|---|---|---|
| `JpegBadMarker` | 不是 JPEG（没有 SOI）或段结构不成形 | 当「不是图片」拒掉 |
| `JpegTruncated` | 字节不够（段长度越界 / 熵段读尽） | 传输/读文件中途断了 |
| `JpegUnsupported` | **我们不做**的合法 JPEG | 说清是哪一类（渐进式/算术/12-bit/4 分量） |
| `JpegCorrupt` | 结构合法但内容自相矛盾 | 文件坏了 |
| `JpegBufferTooSmall` | 编码输出缓冲装不下 | 按 `jpeg_max_bytes` 准备 |
| `ImageBadSize` / `ImageBadChannels` / `ImageOutOfBounds` | `image.uya` 的入参错误 | 调用方 bug |

> **为什么不「尽量解」渐进式**：按基线去解渐进式会得到「上半张对、下半张糊」——
> 那比报错糟得多（使用者看不出是坏的）。所以宁可 `JpegUnsupported`。

## 7. 不变量（改代码前先读）

1. **IDCT 输出立刻夹到 0..255**：不留「超界值等着后面算」的中间态。
2. **每个 MCU 的每个块都必须解出来**：Huffman 码非法 ⇒ `JpegCorrupt`，
   熵段读尽 ⇒ `JpegTruncated`。**绝不用零块顶替** —— 那会产出「右边一条灰」
   这种像图但不对的结果。
3. **色度平面的尺寸按分量取**：`Y` 是 MCU 网格补齐的尺寸，色度是它除以采样因子。
   写块时传错尺寸会**越界写坏相邻缓冲**（症状：上半张对、下半张绿/噪点）。
4. **定标口径统一**：域内量 = 真 DCT 系数（不带 libjpeg 那个 ×8），IDCT 输出 =
   像素差分。改 `jpeg_dct` 的 `DESCALE` 参数时，`test_std_jpeg_encode` 的
   `q=100 → 误差 1` 那条会立刻红。
5. **位读器逐位、不预读**：`pos` 永远指向下一个**未读**的流字节，撞到标记时停在
   它上面。不用 libjpeg 那种「预读 4 字节 + acc 回退」的形状 —— 数据里的 `0xFF00`
   是两个流字节一个数据字节，按字节数回退会落进转义中间（实测在带 `-restart`
   的真图上第 70 个 MCU 处崩）。
6. **RSTn 每 `restart_interval` 个 MCU 一次**（DRI 的单位是 MCU），并在边界复位
   DC 预测器。

## 8. 测试与证据

`make tests` 会跑到（也可单跑）：

```bash
./bin/uya test tests/test_std_jpeg_decode.uya
./bin/uya test tests/test_std_jpeg_encode.uya
# 走完整 C99 后端 + 链接（与 CI 同路径）
./tests/run_programs_parallel.sh -j 8 test_std_jpeg_decode.uya
```

* **解码**：夹具是 `cjpeg` 产的（4:2:0+重启 / 灰度 / 4:4:4 / 渐进式），
  期望值是 `djpeg -nosmooth` 解出来的块均值。覆盖拒绝路径（渐进式 / 非 JPEG /
  截断 / 截断的熵段）与 `jpeg_decode_info`。
* **编码**：自解往返 + 质量单调性 + **逐字节断言 DQT 等于 Annex K** +
  质量两端（q=100 全 1、q=1 夹到 255）+ 缓冲不足 + `jpeg_max_bytes` 够用。
* **跨实现证据**（开发期做过，改 DCT/量化定标时要重做）：我们的编码输出用
  `djpeg -dct int` 能解，平均误差 **1.29/255**、最大 **5/255**（q90、4:2:0、
  64x64 渐变）；我们的解码器与 `djpeg -nosmooth` 在 4:4:4/4:2:2/4:2:0/4:2:0+重启
  四种 256x256 图上逐样本比对，**最大误差 4/255**（196608 个样本，0 个超过 4）。

> 只跑「自己编 → 自己解」的往返会掩盖「两边一起错」。上面那条跨实现证据是
> 定标正确性的**独立**依据，别只依赖往返。

## 9. 相关

* 预算判定与附件落盘（`imgx_*`）在应用层，不在本模块 —— 本模块只负责
  「字节 ↔ 位图」。
* 编写风格与文件头规范见仓库根 `AGENTS.md` 与 `docs/uya.md`。
