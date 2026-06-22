# Neovim 配置（nixvim）— 仅 nixwsl 主机。
# 由 modules/home/default.nix 按 hostname 自动加载。
# LLM 密钥不强制：codecompanion 默认读 OPENAI_API_KEY / ANTHROPIC_API_KEY 环境变量，
# 没设也不影响 vim 启动，只有真用 AI 时才提示缺 key。想用时 export 即可。
{ flake, pkgs, ... }:
let
  # ty 走 stable nixpkgs；25.11 若无则退到 unstable（沿用 opencode.nix 的 ad-hoc 模式）。
  unstablePkgs = import flake.inputs.nixpkgs-unstable { inherit (pkgs) system; };
  tyPkg = pkgs.ty or unstablePkgs.ty;
in
{
  imports = [ flake.inputs.nixvim.homeModules.nixvim ];

  # 字体/图标：SSH 远程连接时由本地终端渲染字体，远程装 Nerd Font 无用。
  # 用 mini.icons 的 ascii 模式：无 Nerd Font 时用首字母大写作图标（lua→L），任何终端无 tofu。
  # mockDevIcons 模拟 nvim-web-devicons，让 lualine/oil/fzf-lua 等自动获得 ascii 图标。
  # 日后本地终端装了 Nerd Font，只需把 style 改为 "glyph" 即可获得完整图标。

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    # === Neovim 选项 ===
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      clipboard = "unnamedplus";
      ignorecase = true;
      smartcase = true;
      termguicolors = true;
    };

    globals.mapleader = " ";

    # === 通用按键（非 LSP）===
    keymaps = [
      { mode = "n"; key = "-"; action = "<cmd>Oil<cr>"; options.desc = "Oil 文件浏览"; }
      { mode = "n"; key = "<C-t>"; action = "<cmd>ToggleTerm<cr>"; options.silent = true; }
      { mode = "t"; key = "<C-t>"; action = "<cmd>ToggleTerm<cr>"; options.silent = true; }
      { mode = [ "n" "v" ]; key = "<leader>a"; action = "<cmd>CodeCompanionActions<cr>"; options.desc = "CodeCompanion actions"; }
      { mode = "n"; key = "<leader>ac"; action = "<cmd>CodeCompanionChat<cr>"; options.desc = "CodeCompanion chat"; }
      { mode = "n"; key = "<leader>hp"; action = "<cmd>Gitsigns preview_hunk<cr>"; options.desc = "Git hunk 预览"; }
      { mode = "n"; key = "<leader>hn"; action = "<cmd>Gitsigns next_hunk<cr>"; options.desc = "Git 下一个 hunk"; }
      { mode = "n"; key = "<leader>hr"; action = "<cmd>Gitsigns reset_hunk<cr>"; options.desc = "Git 重置 hunk"; }
      { mode = "n"; key = "<leader>hs"; action = "<cmd>Gitsigns stage_hunk<cr>"; options.desc = "Git 暂存 hunk"; }
      { mode = "n"; key = "<leader>ut"; action = "<cmd>UndotreeToggle<cr>"; options.desc = "撤销树"; }
      # --- fzf-lua 搜索 ---
      { mode = "n"; key = "<leader>ff"; action = "<cmd>FzfLua files<cr>"; options.desc = "查找文件"; }
      { mode = "n"; key = "<leader>fg"; action = "<cmd>FzfLua live_grep<cr>"; options.desc = "全局内容搜索"; }
      # --- trouble 诊断列表 ---
      { mode = "n"; key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<cr>"; options.desc = "诊断列表"; }
      { mode = "n"; key = "<leader>xr"; action = "<cmd>Trouble lsp toggle<cr>"; options.desc = "LSP 引用/符号"; }
      # --- DAP 调试按键 ---
      { mode = "n"; key = "<leader>b"; action = "<cmd>lua require('dap').toggle_breakpoint()<cr>"; options.desc = "切换断点"; }
      { mode = "n"; key = "<leader>dc"; action = "<cmd>lua require('dap').continue()<cr>"; options.desc = "启动/继续调试"; }
      { mode = "n"; key = "<leader>do"; action = "<cmd>lua require('dap').step_over()<cr>"; options.desc = "step over"; }
      { mode = "n"; key = "<leader>di"; action = "<cmd>lua require('dap').step_into()<cr>"; options.desc = "step into"; }
      { mode = "n"; key = "<leader>du"; action = "<cmd>lua require('dap').step_out()<cr>"; options.desc = "step out"; }
    ];

    # === LSP（原生 vim.lsp，nixvim 封装）===
    # ty 若被 nixvim 列为 unsupported，注释掉 ty 段、启用下方 pyright 退路。
    plugins.lsp = {
      enable = true;
      servers = {
        clangd.enable = true;
        rust_analyzer = {
          enable = true;
          installCargo = false;  # 用系统的 cargo / rustup
          installRustc = false;
        };
        lua_ls.enable = true;
        nil_ls.enable = true;  # Nix 语言 LSP
        ty = {
          enable = true;
          package = tyPkg;
        };
        # pyright.enable = true;  # ty 不可用时的退路
      };
    };

    # LSP 按键：走 LspAttach autocmd；诊断显示配置
    extraConfigLua = ''
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = function(desc) return { buffer = args.buf, desc = desc } end
          local k = vim.keymap.set
          k("n", "gd", vim.lsp.buf.definition, opts("跳转定义"))
          k("n", "gr", vim.lsp.buf.references, opts("引用"))
          k("n", "K", vim.lsp.buf.hover, opts("悬停文档"))
          k("n", "<leader>ca", vim.lsp.buf.code_action, opts("Code action"))
          k("n", "<leader>rn", vim.lsp.buf.rename, opts("重命名"))
          k("n", "<leader>e", vim.diagnostic.open_float, opts("诊断浮窗"))
          k("n", "[d", vim.diagnostic.goto_prev, opts("上一个诊断"))
          k("n", "]d", vim.diagnostic.goto_next, opts("下一个诊断"))
        end,
      })
      -- 诊断显示：行号旁图标 + 行尾虚拟文本
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
      })
    '';

    # === 主题（catppuccin 在 colorschemes 命名空间，不在 plugins）===
    colorschemes.catppuccin = {
      enable = true;
      settings.flavour = "latte";  # 亮色；终端背景需配 #eff1f5
    };

    plugins = {
      # --- 图标提供者（ascii 模式，替代所有 nerd-font hack）---
      mini-icons = {
        enable = true;
        settings.style = "ascii";  # 无 Nerd Font 时用首字母大写图标
        mockDevIcons = true;      # 模拟 nvim-web-devicons，兼容未原生支持 mini.icons 的插件
      };

      # --- 状态栏 + winbar 面包屑 ---
      lualine = {
        enable = true;
        settings = {
          options = {
            icons_enabled = true;  # mini.icons mockDevIcons 提供 ascii 图标
            theme = "auto";       # 跟随 catppuccin
            component_separators = { left = "|"; right = "|"; };
            section_separators = { left = ""; right = ""; };  # 非 powerline 箭头，免 Nerd Font
            globalstatus = true;  # 全局状态栏（neovim 0.7+）
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [ "branch" "diff" "diagnostics" ];
            lualine_c = [
              { __unkeyed-1 = "filename"; path = 3; shorting_target = 150; }  # path=3: 绝对路径，~ 替换 home
            ];
            lualine_x = [ "filetype" ];
            lualine_y = [ "progress" ];
            lualine_z = [ "location" ];
          };
          winbar = {
            lualine_c = [ { __unkeyed-1 = "navic"; } ];  # 面包屑：Class > Method
            lualine_x = [ { __unkeyed-1 = "filename"; path = 3; } ];
          };
          inactive_winbar = {
            lualine_c = [ { __unkeyed-1 = "filename"; path = 3; } ];
          };
        };
      };

      # --- 面包屑导航（LSP 代码上下文，嵌入 lualine winbar）---
      navic = {
        enable = true;
        settings = {
          lsp.auto_attach = true;
          # icons 全部空字符串：面包屑只显示符号名 + " > " 分隔符，无图标依赖
          icons = {
            File = ""; Module = ""; Namespace = ""; Package = ""; Class = "";
            Method = ""; Property = ""; Field = ""; Constructor = ""; Enum = "";
            Interface = ""; Function = ""; Variable = ""; Constant = ""; String = "";
            Number = ""; Boolean = ""; Array = ""; Object = ""; Key = ""; Null = "";
            EnumMember = ""; Struct = ""; Event = ""; Operator = ""; TypeParameter = "";
          };
          highlight = true;  # 用 NavicIcons* 高亮组着色符号名
          separator = " > ";
        };
      };

      # --- 补全（kind_icon 走 mini.icons，ascii 模式无需 Nerd Font）---
      blink-cmp = {
        enable = true;
        settings = {
          sources = {
            default = [ "lsp" "path" "snippets" "buffer" ];
            per_filetype.codecompanion = [ "codecompanion" ];
          };
          snippets.preset = "default";  # 走原生 vim.snippet，无需 LuaSnip
          completion.menu.draw = {
            columns = { __raw = "{ { 'kind_icon' }, { 'label', 'label_description', gap = 1 } }"; };
            components.kind_icon = {
              text.__raw = ''
                function(ctx)
                  local icon, _, _ = require('mini.icons').get('lsp', ctx.kind)
                  return icon
                end
              '';
              highlight.__raw = ''
                function(ctx)
                  local _, hl, _ = require('mini.icons').get('lsp', ctx.kind)
                  return hl
                end
              '';
            };
          };
        };
      };
      friendly-snippets.enable = true;

      # --- AI 编程（多 adapter，chat 里 ga 切换；默认 aliyun）---
      # aliyun: OpenAI-compatible，url/key/model 走环境变量（你手动填 ~/.zprofile）。
      #   未设 ALIYUN_API_URL 回退 DashScope compatible-mode；未设 ALIYUN_MODEL 回退 glm-5.2。
      # copilot: codecompanion 内置 adapter，token 从 ~/.config/github-copilot/hosts.json 读。
      #   codecompanion 自己不发 OAuth，需你自行把 token 填进该文件（从别处复制 / 跑 OAuth）。
      # 切换：chat 里按 ga 选 adapter；或 :CodeCompanion adapter=<name> ...
      codecompanion = {
        enable = true;
        settings = {
          adapters = {
            http = {
              aliyun.__raw = ''
                function()
                  return require("codecompanion.adapters").extend("openai_compatible", {
                    env = {
                      api_key = "ALIYUN_API_KEY",
                      url = function()
                        return os.getenv("ALIYUN_API_URL") or "https://dashscope.aliyuncs.com/compatible-mode/v1"
                      end,
                      chat_url = "/chat/completions",
                      models_endpoint = "/models",
                    },
                    schema = {
                      model = {
                        default = function()
                          return os.getenv("ALIYUN_MODEL") or "glm-5.2"
                        end,
                      },
                    },
                  })
                end
              '';
            };
          };
          strategies = {
            chat.adapter = "aliyun";
            inline.adapter = "aliyun";
            agent.adapter = "aliyun";
          };
          opts.log_level = "INFO";
        };
      };

      # --- 文件浏览 / 模糊搜索（图标走 mini.icons ascii 模式）---
      oil = {
        enable = true;
        settings.columns = [ "icon" "mtime" "size" "permissions" ];  # "icon" 列用 mini.icons
      };
      fzf-lua = {
        enable = true;
        settings.defaults = {
          file_icons = "mini";   # 显式指定 mini.icons 作为图标提供者
          color_icons = true;
        };
      };

      # --- Git ---
      gitsigns.enable = true;

      # --- 跳转 ---
      flash.enable = true;

      # --- 格式化（手动触发：<leader>f 全文件，Visual 下范围）---
      conform-nvim = {
        enable = true;
        settings.formatters_by_ft = {
          c = [ "clang_format" ];
          cpp = [ "clang_format" ];
          rust = [ "rustfmt" ];
          lua = [ "stylua" ];
          python = [ "black" ];
          nix = [ "nixfmt" ];  # nixfmt-rfc-style
        };
      };

      # --- 调试（DAP；nixvim 模块名为 dap，非 nvim-dap）---
      dap.enable = true;
      dap-ui.enable = true;
      dap-python.enable = true;   # debugpy（Python）
      dap-lldb.enable = true;     # codelldb（C / Rust）

      # --- 按键发现（原生支持 mini.icons，ascii 模式无 tofu）---
      which-key = {
        enable = true;
        settings = {
          icons.separator = ">";  # 普通字符，非 powerline 箭头
        };
      };

      # --- 浮动终端 ---
      toggleterm.settings.direction = "float";

      # --- Treesitter ---
      treesitter = {
        enable = true;
        settings.ensure_installed = [ "c" "cpp" "rust" "lua" "python" "vim" "vimdoc" "query" "nix" ];
      };
      treesitter-textobjects.enable = true;

      # --- mini.* ---
      mini-pairs.enable = true;
      mini-surround.enable = true;
      mini-comment.enable = true;
      mini-indentscope.enable = true;

      # --- 撤销树（兼作已 apply 的 AI 编辑回滚）---
      undotree.enable = true;

      # --- 诊断/引用列表 ---
      trouble.enable = true;
    };

    # === conform 格式化按键 ===
    extraConfigLuaPost = ''
      vim.keymap.set("n", "<leader>f", function() require("conform").format() end, { desc = "格式化全文件" })
      vim.keymap.set("v", "<leader>f", function() require("conform").format() end, { desc = "格式化选中范围" })
    '';
  };
}
