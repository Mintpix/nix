# Neovim 配置方案 — nixvim（NixOS + flakes）

从 VSCode 迁移到 Neovim，主打 AI 编程。配置走 **nixvim**（Nix 声明式），并进现有 `~/nix` flake 仓库，密钥走明文文件（自己填，不加密）。当前部署在 **nixwsl** 主机。

> nixvim 用 `nixos-25.11` 分支（跟系统 nixpkgs 配套）。曾试过 main/unstable 追新，但 nixpkgs 26.11 的 `lib.systems.elaborate` 移除了 `linux-kernel`，与 25.11 系统的 buildPlatform 对象冲突报错；25.11 系统下用 `nixos-25.11` 分支才稳。想真正追新需把整个 nixwsl 主机也升到 unstable。

## 决策汇总

| 领域 | nixvim 模块 | 说明 |
|------|------|------|
| **配置框架** | `programs.nixvim`（home-manager） | Nix 声明式，插件由 nixpkgs 提供，`flake.lock` 即锁文件 |
| **主题** | `colorschemes.catppuccin` (Latte) | 亮色；终端背景必须 `#eff1f5` |
| **图标** | `plugins.mini-icons` (ascii) | 无 Nerd Font 时用首字母大写图标；`mockDevIcons` 兼容所有依赖 devicons 的插件 |
| **状态栏** | `plugins.lualine` | mode/branch/diff/diagnostics/文件路径/filetype/progress/location；`globalstatus` |
| **面包屑** | `plugins.navic` + lualine winbar | LSP 代码上下文（Class > Method），嵌入 winbar |
| **补全** | `plugins.blink-cmp` + `friendly-snippets` | pin 版本走 flake.lock；snippets 走原生 `vim.snippet`；kind_icon 走 mini.icons |
| **LSP** | `plugins.lsp.servers.*` | nixvim 封装原生 `vim.lsp`，无需 lspconfig/Mason |
| **AI 编程** | `plugins.codecompanion` | Chat + Inline（diff/apply 原生）+ Agent + MCP；默认 aliyun adapter |
| **文件浏览** | `plugins.oil` | 编辑式目录管理；图标走 mini.icons |
| **模糊搜索** | `plugins.fzf-lua` | 基于 fzf；`file_icons = "mini"` |
| **Git** | `plugins.gitsigns` | 行级改动 + hunk 操作（预览/导航/暂存/重置） |
| **诊断列表** | `plugins.trouble` | 诊断/引用/符号列表 |
| **跳转** | `plugins.flash` | 1-2 字符精确跳转 |
| **格式化** | `plugins.conform-nvim` | 手动 + Visual 范围格式化 |
| **调试** | `plugins.nvim-dap` + `dap-ui`/`dap-python`/`dap-lldb` | 断点、变量、调用栈 |
| **按键发现** | `plugins.which-key` | 前缀键弹出面板；原生支持 mini.icons |
| **终端** | `plugins.toggleterm` | 浮动终端 |
| **Treesitter** | `plugins.treesitter` + `treesitter-textobjects` | parser 由 nixpkgs 装 |
| **Auto-pairs** | `plugins.mini-pairs` | 自动括号 |
| **Surround** | `plugins.mini-surround` | 加/改/删包裹 |
| **注释切换** | `plugins.mini-comment` | `gcc` / `gc` |
| **缩进可视化** | `plugins.mini-indentscope` | 动画缩进线 |
| **撤销** | `plugins.undotree` | 撤销树；兼作已 apply 的 AI 编辑回滚 |

## 语言栈 & 对应工具

| 语言 | LSP（nixvim） | Treesitter | Formatter | DAP |
|------|-----|-------------------|-----------|------|
| C/C++ | `clangd` | `c`/`cpp` | `clang-format` | `dap-lldb`（codelldb） |
| Rust | `rust_analyzer` | `rust` | `rustfmt`（rustc 自带） | `dap-lldb` |
| Lua | `lua_ls` | `lua` | `stylua` | — |
| Python | `ty`（stable 无则 unstable；退路 `pyright`） | `python` | `black` | `dap-python`（debugpy） |

所有 LSP/formatter/DAP 走 **nixpkgs**（不走 Mason——NixOS 下 Mason 与 nix store 二进制冲突）。

## 文件位置（在 `~/nix` 仓库内）

```
~/nix/
├── flake.nix                          # 已加 nixvim 输入（nixos-25.11 分支）
├── flake.lock                         # 唯一锁文件（含 nixvim + 所有插件版本）
├── secrets/secrets.yaml               # sops 加密；加 openai_api_key / anthropic_api_key
├── configurations/nixos/nixwsl.nix    # 导入 sops + owner 覆盖（mp 可读密钥）
└── modules/home/nixwsl/nixvim.nix     # ★ 全部 nvim 配置（host-specific，仅 nixwsl）
```

`modules/home/default.nix` 按 `hostname` 自动加载 `modules/home/<hostname>/*.nix`，故 `nixwsl/nixvim.nix` 只对 nixwsl 生效，零侵入其他主机。

## 配置要点

### 1. nixvim 模块化

一个文件 `modules/home/nixwsl/nixvim.nix` 承载全部配置：`programs.nixvim = { enable; opts; keymaps; plugins = {...}; extraConfigLua; }`。插件用 `plugins.X.enable = true` + `plugins.X.settings = {...}`（`settings` 任意 attrset 直接透传给插件的 `setup()`）。不够用时 `extraConfigLua` 写原生 lua。

### 2. blink.cmp — 补全

`settings` 透传给 blink 的 `setup()`，版本由 `flake.lock` 锁定（无需 `version = ...`）。snippets 走原生 `vim.snippet`（无需 LuaSnip）。codecompanion 的 blink source 在 chat buffer 里给 `/` `#` `@` 补全：

```nix
plugins.blink-cmp = {
  enable = true;
  settings = {
    sources = {
      default = [ "lsp" "path" "snippets" "buffer" ];
      per_filetype.codecompanion = [ "codecompanion" ];
    };
    snippets.preset = "default";
  };
};
plugins.friendly-snippets.enable = true;
```

### 3. LSP（nixvim 封装）

`plugins.lsp.servers.<name>.enable = true`，nixvim 自动管 `cmd` / `root_dir`（`.git` 兜底已内置）。`ty` 若被 nixvim 列为 unsupported，注释掉换 `pyright`：

```nix
plugins.lsp.servers = {
  clangd.enable = true;
  rust_analyzer.enable = true;
  lua_ls.enable = true;
  ty = { enable = true; package = pkgs.ty or (import flake.inputs.nixpkgs-unstable { inherit (pkgs) system; }).ty; };
  # pyright.enable = true;  # ty 不可用时的退路
};
```

LSP 按键走 `LspAttach` autocmd（`extraConfigLua`），避免猜 nixvim 的 `lsp.keymaps` 选项结构：`gd`/`gr`/`K`/`<leader>ca`/`<leader>rn`/`<leader>e`/`[d`/`]d`。

### 4. conform.nvim — 范围格式化

```nix
plugins.conform-nvim = {
  enable = true;
  settings.formatters_by_ft = {  # snake_case，透传给 lua setup()
    c = [ "clang_format" ]; cpp = [ "clang_format" ];
    rust = [ "rustfmt" ]; lua = [ "stylua" ]; python = [ "black" ];
  };
};
# 按键在 extraConfigLuaPost：<leader>f 全文件 / Visual 下选中范围
```

### 5. nvim-dap — 调试

nixvim 模块名为 `dap`（不是 `nvim-dap`）：

```nix
plugins.dap.enable = true;
plugins.dap-ui.enable = true;
plugins.dap-python.enable = true;   # debugpy
plugins.dap-lldb.enable = true;     # codelldb（C/Rust）
# 按键已在 keymaps 列表里：<leader>b 断点 / <leader>dc 启动 / <leader>do over / di into / du out
```

### 6. codecompanion.nvim — AI 编程（主力场景）

默认 adapter 为 `openai`，密钥**不进配置**——由 sops-nix 解密到 `/run/secrets/openai_api_key`，codecompanion 用 `env.api_key` 函数读取。需要顶级质量时 `:<','>CodeCompanion adapter=anthropic ...` 临时切。

```nix
let
  readSecretLua = name: ''
    function()
      local lines = vim.fn.readfile("/run/secrets/${name}")
      if not lines or not lines[1] then
        error("codecompanion: sops secret ${name} 不可读")
      end
      return lines[1]
    end
  '';
  adapterLua = adapter: secret: ''
    function()
      return require("codecompanion.adapters").extend("${adapter}", {
        env = { api_key = ${readSecretLua secret} },
      })
    end
  '';
in {
  plugins.codecompanion = {
    enable = true;
    settings = {
      adapters = {
        openai.__raw = adapterLua "openai" "openai_api_key";
        anthropic.__raw = adapterLua "anthropic" "anthropic_api_key";
      };
      strategies = {
        chat.adapter = "openai";
        inline.adapter = "openai";
        agent.adapter = "openai";
      };
    };
  };
}
```

### 6.1 AI 编程工作流要点（务必熟悉）

codecompanion 的 inline interaction 是核心交互，开箱即用：

- **Diff 预览**：默认开启。inline prompt 触发后自动展示原 buffer 与 LLM 改动的 diff。
- **接受 / 拒绝**（pending 状态下）：`gda` 接受、`gdr` 拒绝。
- **已 accept 的回滚**：codecompanion 无专属 revid 按钮；用 `u` 撤销，或 `:Undotree` 在可视化撤销树跳到任意历史节点（比 avante 的 revid 更强）。
- **Inline 用法**：`:CodeCompanion <prompt>` 或 visual 选中后 `:'<,'>CodeCompanion <prompt>`；带 prompt library 如 `:'<,'>CodeCompanion /tests`。
- **Editor Context**：`#{buffer}` / `#{chat}` / `#{clipboard}`，例：`:CodeCompanion #{buffer} 给这个文件加一个方法`。
- **临时切 adapter**：`:'<,'>CodeCompanion adapter=anthropic 重构这段`。

### 7. 多 Adapter 与密钥管理（aliyun 默认 + copilot）

codecompanion 支持多 adapter，chat 里 `ga` 交互切换。配两个：

**aliyun**（默认）— OpenAI-compatible，走环境变量（手动填 `~/.zprofile`）：

```sh
# ~/.zprofile（未被 home-manager 托管，重建不覆盖）
export ALIYUN_API_KEY="sk-..."
export ALIYUN_API_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"  # base 含 /v1
export ALIYUN_MODEL="glm-5.2"   # 默认模型；不设也回退到 glm-5.2
```

```nix
plugins.codecompanion.settings.adapters.http.aliyun.__raw = ''
  function()
    return require("codecompanion.adapters").extend("openai_compatible", {
      env = {
        api_key = "ALIYUN_API_KEY",
        url = function() return os.getenv("ALIYUN_API_URL") or "https://dashscope.aliyuncs.com/compatible-mode/v1" end,
        chat_url = "/chat/completions",
        models_endpoint = "/models",
      },
      schema = { model = { default = function() return os.getenv("ALIYUN_MODEL") or "glm-5.2" end } },
    })
  end
'';
# strategies 默认全用 aliyun
```

**copilot** — codecompanion 内置 adapter，token 从 `~/.config/github-copilot/hosts.json` 读。codecompanion 自己不发 OAuth，需你**自行把 token 填进该文件**（从别处复制 / 跑 OAuth；不装 copilot-lua 等插件）。未填则用 copilot adapter 时报缺 token。

```nix
# 仅 codecompanion，copilot adapter 走内置 preset，无需额外插件
plugins.codecompanion.settings.strategies = {
  chat.adapter = "aliyun";   # 默认 aliyun；切 copilot 用 ga
  inline.adapter = "aliyun";
  agent.adapter = "aliyun";
};
```

**切换方式**：
- chat buffer 内 `ga` → 选 `aliyun` 或 `copilot`（adapter 有多模型时再选 model）
- per-request：`:'<,'>CodeCompanion adapter=copilot ...`
- debug 窗口 `gd` 改 adapter/model/settings，`<C-s>` 持久化

不设 aliyun 环境变量时：URL 回退 DashScope，model 回退 glm-5.2，key 缺则 AI 请求时报错，vim 本身正常。copilot 未 auth 则用 copilot adapter 时报缺 token。

### 8. which-key / toggleterm / oil

```nix
plugins.which-key.enable = true;
plugins.toggleterm.settings.direction = "float";
plugins.oil.enable = true;
# keymaps：<C-t> 浮动终端、- 打开 oil、<leader>a codecompanion
```

### 9. mini.icons — 图标提供者（ascii 模式）

替代所有 nerd-font hack。`style = "ascii"` 在无 Nerd Font 时用首字母大写图标，`mockDevIcons = true` 模拟 `nvim-web-devicons` 让未原生支持 mini.icons 的插件也能用：

```nix
plugins.mini-icons = {
  enable = true;
  settings.style = "ascii";  # 无 Nerd Font 时用首字母图标
  mockDevIcons = true;      # 兼容 lualine/oil/fzf-lua 等
};
```

blink-cmp 的 `kind_icon` 通过 `mini.icons.get("lsp", ctx.kind)` 获取图标和高亮组。which-key 原生支持 mini.icons，无需额外配置。

### 10. lualine + navic — 状态栏与面包屑

lualine 配置完整的 `sections`（底部状态栏）和 `winbar`（顶部面包屑）：

```nix
plugins.lualine.settings = {
  options = {
    icons_enabled = true;       # mini.icons mockDevIcons 提供 ascii 图标
    theme = "auto";
    globalstatus = true;
    component_separators = { left = "|"; right = "|"; };
    section_separators = { left = ""; right = ""; };  # 非 powerline 箭头
  };
  sections = {
    lualine_a = [ "mode" ];
    lualine_b = [ "branch" "diff" "diagnostics" ];
    lualine_c = [{ __unkeyed-1 = "filename"; path = 3; shorting_target = 150; }];  # 绝对路径
    lualine_x = [ "filetype" ];
    lualine_y = [ "progress" ];
    lualine_z = [ "location" ];
  };
  winbar = {
    lualine_c = [ { __unkeyed-1 = "navic"; } ];       # 面包屑：Class > Method
    lualine_x = [ { __unkeyed-1 = "filename"; path = 3; } ];
  };
};
```

navic 通过 `lsp.auto_attach = true` 自动 attach 到所有 LSP，icons 全部设为空字符串（面包屑只显示符号名 + ` > ` 分隔符）：

```nix
plugins.navic = {
  enable = true;
  settings = {
    lsp.auto_attach = true;
    highlight = true;
    separator = " > ";
    # icons 全部空字符串，无图标依赖
  };
};
```

## 用法速查（按键 / 命令）

`<leader>` = `<space>`。

### 文件 / 导航 / 终端

| 按键 | 插件 | 作用 |
|---|---|---|
| `-` | oil | 打开当前目录（编辑式：改文件名=重命名、`dd`=删除、新行=创建文件） |
| `<C-t>` | toggleterm | 弹出/隐藏浮动终端（终端内也生效） |
| `s` + 2 字符 | flash | 跳转到屏幕任意位置（Normal/Visual 都行） |
| `<leader>ff` | fzf-lua | 查找文件 |
| `<leader>fg` | fzf-lua | 全局内容搜索 |

### 编辑 / 格式化 / 撤销

| 按键 | 插件 | 作用 |
|---|---|---|
| `<leader>f` | conform | 格式化（Normal=全文件，Visual=选中范围） |
| `gcc` | mini.comment | 注释/取消注释当前行 |
| `gc`（Visual） | mini.comment | 注释选中块 |
| `sa`/`sd`/`sr` | mini.surround | 加/删/改包裹符号（如 `saiw)` 给词加括号） |
| `<leader>ut` | undotree | 打开撤销树（跳任意历史节点，兼作 AI 编辑回滚） |

补全（blink-cmp）：输入时自动弹菜单，`Tab`/`Shift-Tab` 上下选、`Enter` 接受。

### LSP（代码智能）

| 按键 | 作用 |
|---|---|
| `gd` | 跳转定义 |
| `gr` | 引用 |
| `K` | 悬停文档 |
| `<leader>ca` | Code action |
| `<leader>rn` | 重命名 |
| `<leader>e` | 诊断浮窗 |
| `[d` / `]d` | 上/下一个诊断 |

### Git（gitsigns）

| 按键 | 作用 |
|---|---|
| `<leader>hp` | 预览当前 hunk |
| `<leader>hn` | 下一个 hunk |
| `<leader>hr` | 重置当前 hunk |
| `<leader>hs` | 暂存当前 hunk |
| `:Gitsigns` | 其他 hunk 操作 |

### 诊断（trouble）

| 按键 | 作用 |
|---|---|
| `<leader>xx` | 诊断列表（toggle） |
| `<leader>xr` | LSP 引用/符号列表 |

### 调试（nvim-dap）

| 按键 | 作用 |
|---|---|
| `<leader>b` | 切换断点 |
| `<leader>dc` | 启动 / 继续调试 |
| `<leader>do` | step over |
| `<leader>di` | step into |
| `<leader>du` | step out |

### AI 编程（codecompanion，主力）

| 按键 / 命令 | 作用 |
|---|---|
| `<leader>a` | CodeCompanion 动作面板 |
| `<leader>ac` | 开 chat |
| `:CodeCompanion <prompt>` | inline 改写（光标处） |
| `:'<,'>CodeCompanion <prompt>` | 改写选中代码 |
| `:'<,'>CodeCompanion /tests` | 用 prompt library（如生成测试） |
| `#{buffer}` / `#{clipboard}` | inline 里塞 editor context |
| **chat 内** `ga` | 切 adapter（aliyun / copilot），多模型再选 model |
| **chat 内** `gd` | debug 窗口（改 adapter/model/settings，`<C-s>` 存） |
| **chat 内** `gr` | 重新生成 |
| **chat 内** `gc` | 插入 codeblock |
| **chat 内** `?` | 看全部 chat 按键 |
| **inline diff** `gda` | 接受 AI 改动 |
| **inline diff** `gdr` | 拒绝 AI 改动 |
| `:CodeCompanion adapter=copilot ...` | per-request 临时切 adapter |

切 model：chat 内 `ga` 选 adapter 后若有多模型会再弹选择。aliyun 的 model 也由 `ALIYUN_MODEL` 环境变量控制（默认 glm-5.2）。

### which-key

按 `<space>` 弹出后续可用按键面板（前缀发现）。任何 `<leader>` 前缀都会触发。

## 构建与部署

```sh
cd ~/nix
# 1.（手动，一次性）~/.zprofile 填 aliyun 环境变量（该文件未被 home-manager 托管）
#    export ALIYUN_API_KEY="sk-..."
#    export ALIYUN_API_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"
#    export ALIYUN_MODEL="glm-5.2"
# 2.（仅首次用 copilot）自行把 GitHub Copilot token 填进 ~/.config/github-copilot/hosts.json
# 3. 重建
sudo nixos-rebuild switch --flake .#nixwsl
# 或 nixos-unified: nix run .#activate
```

改 nixvim 配置后同样 `nixos-rebuild switch`。`nix flake update nixvim` 升级 nixvim（连带插件版本）。

## 注意事项

- **nixvim 版本**：用 `nixos-25.11` 分支，跟系统 nixpkgs 配套。试过 main/unstable 追新，但 nixpkgs 26.11 `lib.systems.elaborate` 移除 `linux-kernel`，与 25.11 系统 buildPlatform 冲突报错。想追新需把 nixwsl 主机整体升到 unstable nixpkgs。
- **Treesitter parser**：`plugins.treesitter.settings.ensure_installed` 由 nixpkgs 编译时装好，无需 `:TSInstall`。
- **LSP/formatter/DAP 二进制**：全走 nixpkgs，无需 `:Mason`。Mason 在 NixOS 下会与 nix store 二进制冲突，已弃用。
- **图标（mini.icons ascii 模式）**：SSH 远程连接时字体由**本地终端**渲染，远程装 Nerd Font 无用。本配置用 `mini.icons` 的 `style = "ascii"` 模式——无 Nerd Font 时用首字母大写作图标（lua→`L`、rust→`R`），配合 `mockDevIcons = true` 让 lualine/oil/fzf-lua 等自动获得 ascii 图标，任何终端直连都不出现 tofu。blink-cmp 和 which-key 原生支持 mini.icons。若日后想要完整字形图标，在**本地**终端装 Nerd Font，然后把 `mini-icons.settings.style` 改为 `"glyph"` 即可。
- **Latte 主题 + 终端背景（必做）**：终端背景**必须** `#eff1f5`，前景 `#4c4f69`，否则 lualine / 浮动窗口 / codecompanion chat 与深色终端割裂。终端设浅色模式。
- **ty 兜底**：`pkgs.ty or unstable.ty`；若 nixvim 把 ty 列为 unsupported server，注释掉 ty 段启用 `pyright`。
- **flake.lock 唯一锁文件**：不再有 `nvim-pack-lock.json`，插件版本全靠 `flake.lock`。

## 出名配置参考

- **nixvim 官方** — https://github.com/nix-community/nixvim / https://nix-community.github.io/nixvim ：所有 `plugins.X` 选项的权威文档。
- **nixvim 真实配置集** — https://nix-community.github.io/nixvim/user-guide/config-examples.html ：社区真实 nixvim 配置列表。
- **GaetanLepage 的 dotfiles** — https://github.com/GaetanLepage/dotfiles ：nixvim 维护者的个人配置，最完整的范式参考。
- **codecompanion 文档** — https://codecompanion.olimorris.dev ：adapters / inline / MCP 逐页看。
- **Fredrik Averpil dotfiles**（vim.pack 路线，作对照）— https://github.com/fredrikaverpil/dotfiles ：非 nixvim 路线下的从零范式，`lua/lazyload.lua` 可借鉴。
