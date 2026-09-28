#!/usr/bin/env bash
set -Eeuo pipefail

LOGFILE="/workspace/qwen_bfs_setup.log"
mkdir -p /workspace
exec > >(tee -a "$LOGFILE") 2>&1

say() { echo; echo "============================================================"; echo "$1"; echo "============================================================"; }

find_comfy() {
  for d in /workspace/ComfyUI /root/ComfyUI "$HOME/ComfyUI"; do
    if [ -d "$d" ]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

install_or_update_repo() {
  local url="$1"
  local dest="$2"
  if [ -d "$dest/.git" ]; then
    echo "Updating $(basename "$dest")"
    git -C "$dest" pull --ff-only || true
  elif [ -d "$dest" ]; then
    echo "Directory exists but is not a git repo: $dest"
  else
    echo "Cloning $url -> $dest"
    git clone --depth 1 "$url" "$dest"
  fi
  if [ -f "$dest/requirements.txt" ]; then
    python3 -m pip install -r "$dest/requirements.txt" || python -m pip install -r "$dest/requirements.txt" || true
  fi
  if [ -f "$dest/requirements.pip" ]; then
    python3 -m pip install -r "$dest/requirements.pip" || python -m pip install -r "$dest/requirements.pip" || true
  fi
  if [ -f "$dest/install.py" ]; then
    python3 "$dest/install.py" || python "$dest/install.py" || true
  fi
}

download_file() {
  local url="$1"
  local out="$2"
  mkdir -p "$(dirname "$out")"
  if [ -f "$out" ]; then
    echo "Already exists: $out"
    return 0
  fi
  echo "Downloading: $url"
  wget -c "$url" -O "$out" || curl -L "$url" -o "$out"
}

say "Locating / installing ComfyUI"
COMFY_DIR="$(find_comfy || true)"
if [ -z "$COMFY_DIR" ]; then
  cd /workspace
  git clone https://github.com/Comfy-Org/ComfyUI.git
  COMFY_DIR=/workspace/ComfyUI
fi

echo "COMFY_DIR=$COMFY_DIR"

say "Updating ComfyUI core"
git -C "$COMFY_DIR" pull --ff-only || true
python3 -m pip install -U pip || true
if [ -f "$COMFY_DIR/requirements.txt" ]; then
  python3 -m pip install -r "$COMFY_DIR/requirements.txt" || python -m pip install -r "$COMFY_DIR/requirements.txt" || true
fi

say "Creating model folders"
mkdir -p "$COMFY_DIR/models/diffusion_models"
mkdir -p "$COMFY_DIR/models/text_encoders"
mkdir -p "$COMFY_DIR/models/vae"
mkdir -p "$COMFY_DIR/models/loras"
mkdir -p "$COMFY_DIR/custom_nodes"
mkdir -p "$COMFY_DIR/user/default/workflows"

say "Installing required custom nodes for BFS workflow"
install_or_update_repo "https://github.com/kijai/ComfyUI-KJNodes.git" "$COMFY_DIR/custom_nodes/ComfyUI-KJNodes"
install_or_update_repo "https://gitlab.com/pixaroma/comfyui-pixaroma.git" "$COMFY_DIR/custom_nodes/comfyui-pixaroma"
install_or_update_repo "https://github.com/rgthree/rgthree-comfy.git" "$COMFY_DIR/custom_nodes/rgthree-comfy"
install_or_update_repo "https://github.com/ClownsharkBatwing/RES4LYF.git" "$COMFY_DIR/custom_nodes/RES4LYF"

say "Downloading Qwen Image 2.1 core models"
download_file "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_int8_convrot.safetensors" "$COMFY_DIR/models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors"
download_file "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors" "$COMFY_DIR/models/text_encoders/qwen3vl_8b_int8_convrot.safetensors"
download_file "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors" "$COMFY_DIR/models/vae/qwen_image_2.1_vae_bf16.safetensors"

say "Downloading BFS / Pruna LoRAs"
download_file "https://huggingface.co/Alissonerdx/BFS-Best-Face-Swap/resolve/main/bfs_head_v1_qwen_2.1.safetensors" "$COMFY_DIR/models/loras/bfs_head_v1_qwen_2.1.safetensors"
download_file "https://huggingface.co/PrunaAI/Pruna-Qwen-Image-2.1/resolve/main/p_qwen_image_2.1_8step_v0.1.safetensors" "$COMFY_DIR/models/loras/p_qwen_image_2.1_8step_v0.1.safetensors"

say "Writing ready-to-use BFS workflow"
cat > "$COMFY_DIR/user/default/workflows/Qwen2.1-BFS-Head-V1-Workflow.json" <<'JSON'
{
  "id": "54bb395d-3e60-4c94-b525-85523901575b",
  "revision": 0,
  "last_node_id": 524,
  "last_link_id": 827,
  "nodes": [
    {
      "id": 472,
      "type": "ImageCompare",
      "pos": [
        9296.368908118156,
        2564.443312668747
      ],
      "size": [
        660,
        760
      ],
      "flags": {},
      "order": 0,
      "mode": 0,
      "inputs": [
        {
          "name": "image_a",
          "shape": 7,
          "type": "IMAGE",
          "link": null
        },
        {
          "name": "image_b",
          "shape": 7,
          "type": "IMAGE",
          "link": null
        }
      ],
      "outputs": [],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "ImageCompare",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      },
      "widgets_values": [],
      "widgets_values_named": {}
    },
    {
      "id": 509,
      "type": "SetNode",
      "pos": [
        2302.0722316120437,
        2053.81880583063
      ],
      "size": [
        210,
        50
      ],
      "flags": {
        "collapsed": true
      },
      "order": 24,
      "mode": 0,
      "inputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "link": 813
        }
      ],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": []
        }
      ],
      "title": "Set_head_reference",
      "properties": {
        "Node name for S&R": "SetNode",
        "aux_id": "kijai/ComfyUI-KJNodes",
        "previousName": "head_reference"
      },
      "widgets_values": [
        "head_reference"
      ],
      "widgets_values_named": {
        "Constant": "head_reference"
      },
      "color": "#2a363b",
      "bgcolor": "#3f5159"
    },
    {
      "id": 513,
      "type": "SetNode",
      "pos": [
        2294.2297018614677,
        1977.5930749307531
      ],
      "size": [
        210,
        50
      ],
      "flags": {
        "collapsed": true
      },
      "order": 27,
      "mode": 0,
      "inputs": [
        {
          "name": "INT",
          "type": "INT",
          "link": 819
        }
      ],
      "outputs": [
        {
          "name": "INT",
          "type": "INT",
          "links": []
        }
      ],
      "title": "Set_height",
      "properties": {
        "Node name for S&R": "SetNode",
        "aux_id": "kijai/ComfyUI-KJNodes",
        "previousName": "height"
      },
      "widgets_values": [
        "height"
      ],
      "widgets_values_named": {
        "Constant": "height"
      },
      "color": "#1b4669",
      "bgcolor": "#29699c"
    },
    {
      "id": 512,
      "type": "SetNode",
      "pos": [
        2291.6133371690134,
        1938.0303629713444
      ],
      "size": [
        210,
        60
      ],
      "flags": {
        "collapsed": true
      },
      "order": 26,
      "mode": 0,
      "inputs": [
        {
          "name": "INT",
          "type": "INT",
          "link": 817
        }
      ],
      "outputs": [
        {
          "name": "INT",
          "type": "INT",
          "links": null
        }
      ],
      "title": "Set_width",
      "properties": {
        "Node name for S&R": "SetNode",
        "aux_id": "kijai/ComfyUI-KJNodes",
        "previousName": "width"
      },
      "widgets_values": [
        "width"
      ],
      "widgets_values_named": {
        "Constant": "width"
      },
      "color": "#1b4669",
      "bgcolor": "#29699c"
    },
    {
      "id": 505,
      "type": "SetNode",
      "pos": [
        2293.9377511826247,
        1893.346192895989
      ],
      "size": [
        210,
        60
      ],
      "flags": {
        "collapsed": true
      },
      "order": 25,
      "mode": 0,
      "inputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "link": 805
        }
      ],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": []
        }
      ],
      "title": "Set_body_reference",
      "properties": {
        "Node name for S&R": "SetNode",
        "aux_id": "kijai/ComfyUI-KJNodes",
        "previousName": "body_reference"
      },
      "widgets_values": [
        "body_reference"
      ],
      "widgets_values_named": {
        "Constant": "body_reference"
      },
      "color": "#2a363b",
      "bgcolor": "#3f5159"
    },
    {
      "id": 13,
      "type": "ResolutionSelector",
      "pos": [
        1654.0764422324858,
        1909.6117073638825
      ],
      "size": [
        300,
        190
      ],
      "flags": {},
      "order": 1,
      "mode": 0,
      "showAdvanced": true,
      "inputs": [],
      "outputs": [
        {
          "name": "width",
          "type": "INT",
          "links": [
            735,
            737
          ]
        },
        {
          "name": "height",
          "type": "INT",
          "links": [
            736,
            738
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "ResolutionSelector",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      },
      "widgets_values": [
        "1:1 (Square)",
        2,
        32
      ],
      "widgets_values_named": {
        "aspect_ratio": "1:1 (Square)",
        "megapixels": 2,
        "multiple": 32
      }
    },
    {
      "id": 514,
      "type": "GetNode",
      "pos": [
        3376.9188156397736,
        2624.337951069355
      ],
      "size": [
        210,
        60
      ],
      "flags": {
        "collapsed": true
      },
      "order": 2,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "INT",
          "type": "INT",
          "links": [
            820
          ]
        }
      ],
      "title": "Get_width",
      "properties": {
        "Node name for S&R": "GetNode",
        "aux_id": "kijai/ComfyUI-KJNodes"
      },
      "widgets_values": [
        "width"
      ],
      "widgets_values_named": {
        "Constant": "width"
      },
      "color": "#1b4669",
      "bgcolor": "#29699c"
    },
    {
      "id": 515,
      "type": "GetNode",
      "pos": [
        3380.726997985999,
        2675.818839566489
      ],
      "size": [
        210,
        60
      ],
      "flags": {
        "collapsed": true
      },
      "order": 3,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "INT",
          "type": "INT",
          "links": [
            821
          ]
        }
      ],
      "title": "Get_height",
      "properties": {
        "Node name for S&R": "GetNode",
        "aux_id": "kijai/ComfyUI-KJNodes"
      },
      "widgets_values": [
        "height"
      ],
      "widgets_values_named": {
        "Constant": "height"
      },
      "color": "#1b4669",
      "bgcolor": "#29699c"
    },
    {
      "id": 486,
      "type": "EmptyLatentImage",
      "pos": [
        3564.0211792895375,
        2594.8540561338486
      ],
      "size": [
        300,
        120
      ],
      "flags": {},
      "order": 19,
      "mode": 0,
      "inputs": [
        {
          "name": "width",
          "type": "INT",
          "widget": {
            "name": "width"
          },
          "link": 820
        },
        {
          "name": "height",
          "type": "INT",
          "widget": {
            "name": "height"
          },
          "link": 821
        }
      ],
      "outputs": [
        {
          "name": "LATENT",
          "type": "LATENT",
          "links": [
            788
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "EmptyLatentImage",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      },
      "widgets_values": [
        1024,
        1024,
        1
      ],
      "widgets_values_named": {
        "width": 1024,
        "height": 1024,
        "batch_size": 1
      }
    },
    {
      "id": 487,
      "type": "VAEDecode",
      "pos": [
        4630.831121045059,
        1820.8668411324347
      ],
      "size": [
        230,
        60
      ],
      "flags": {},
      "order": 31,
      "mode": 0,
      "inputs": [
        {
          "name": "samples",
          "type": "LATENT",
          "link": 756
        },
        {
          "name": "vae",
          "type": "VAE",
          "link": 754
        }
      ],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            755
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "VAEDecode",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      }
    },
    {
      "id": 508,
      "type": "GetNode",
      "pos": [
        5339.8428287461,
        1825.6876660167668
      ],
      "size": [
        210,
        58
      ],
      "flags": {
        "collapsed": true
      },
      "order": 4,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            810
          ]
        }
      ],
      "title": "Get_body_reference",
      "properties": {
        "Node name for S&R": "GetNode",
        "aux_id": "kijai/ComfyUI-KJNodes"
      },
      "widgets_values": [
        "body_reference"
      ],
      "widgets_values_named": {
        "Constant": "body_reference"
      },
      "color": "#2a363b",
      "bgcolor": "#3f5159"
    },
    {
      "id": 511,
      "type": "GetNode",
      "pos": [
        5342.331453192015,
        1878.788296432007
      ],
      "size": [
        210,
        58
      ],
      "flags": {
        "collapsed": true
      },
      "order": 5,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            816
          ]
        }
      ],
      "title": "Get_head_reference",
      "properties": {
        "Node name for S&R": "GetNode",
        "aux_id": "kijai/ComfyUI-KJNodes"
      },
      "widgets_values": [
        "head_reference"
      ],
      "widgets_values_named": {
        "Constant": "head_reference"
      },
      "color": "#2a363b",
      "bgcolor": "#3f5159"
    },
    {
      "id": 507,
      "type": "GetNode",
      "pos": [
        6014.930347025126,
        1936.6873908094537
      ],
      "size": [
        210,
        58
      ],
      "flags": {
        "collapsed": true
      },
      "order": 6,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            825
          ]
        }
      ],
      "title": "Get_body_reference",
      "properties": {
        "Node name for S&R": "GetNode",
        "aux_id": "kijai/ComfyUI-KJNodes"
      },
      "widgets_values": [
        "body_reference"
      ],
      "widgets_values_named": {
        "Constant": "body_reference"
      },
      "color": "#2a363b",
      "bgcolor": "#3f5159"
    },
    {
      "id": 477,
      "type": "ImageResizeKJv2",
      "pos": [
        2078.2319539073947,
        1994.5553372884267
      ],
      "size": [
        290.6913531671082,
        336
      ],
      "flags": {
        "collapsed": true
      },
      "order": 21,
      "mode": 0,
      "inputs": [
        {
          "name": "image",
          "type": "IMAGE",
          "link": 823
        },
        {
          "name": "mask",
          "shape": 7,
          "type": "MASK",
          "link": null
        },
        {
          "name": "width",
          "type": "INT",
          "widget": {
            "name": "width"
          },
          "link": 735
        },
        {
          "name": "height",
          "type": "INT",
          "widget": {
            "name": "height"
          },
          "link": 736
        }
      ],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            805
          ]
        },
        {
          "name": "width",
          "type": "INT",
          "links": [
            817
          ]
        },
        {
          "name": "height",
          "type": "INT",
          "links": [
            819
          ]
        },
        {
          "name": "mask",
          "type": "MASK",
          "links": null
        }
      ],
      "properties": {
        "cnr_id": "comfyui-kjnodes",
        "ver": "60cd6bc1870db94c6eeb05fbe455147a8e91c4e9",
        "Node name for S&R": "ImageResizeKJv2",
        "ue_properties": {
          "widget_ue_connectable": {},
          "input_ue_unconnectable": {},
          "version": "7.5.1"
        }
      },
      "widgets_values": [
        512,
        512,
        "lanczos",
        "resize",
        "0, 0, 0",
        "center",
        32,
        "cpu"
      ],
      "widgets_values_named": {
        "width": 512,
        "height": 512,
        "upscale_method": "lanczos",
        "keep_proportion": "resize",
        "pad_color": "0, 0, 0",
        "crop_position": "center",
        "divisible_by": 32,
        "device": "cpu"
      }
    },
    {
      "id": 499,
      "type": "AddLabel",
      "pos": [
        5926.303463962263,
        1840.8792177949715
      ],
      "size": [
        270,
        270
      ],
      "flags": {
        "collapsed": true
      },
      "order": 35,
      "mode": 0,
      "inputs": [
        {
          "name": "image",
          "type": "IMAGE",
          "link": 793
        },
        {
          "name": "caption",
          "shape": 7,
          "type": "STRING",
          "link": null
        }
      ],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            824
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfyui-kjnodes",
        "ver": "60cd6bc1870db94c6eeb05fbe455147a8e91c4e9",
        "Node name for S&R": "AddLabel",
        "ue_properties": {
          "widget_ue_connectable": {},
          "input_ue_unconnectable": {},
          "version": "7.5.1"
        }
      },
      "widgets_values": [
        10,
        2,
        82,
        24,
        "white",
        "black",
        "FreeMono.ttf",
        "head_swap: start with <image1> as the base image, keeping its lighting, environment, and background. remove the head from <image1> completely and replace it with the head from <image2>, strictly preserving the hair, eye color, nose structure from <image2>. copy the direction of the eye, head rotation, micro expressions from <image1>, high quality, sharp details, 4k",
        "down"
      ],
      "widgets_values_named": {
        "text_x": 10,
        "text_y": 2,
        "height": 82,
        "font_size": 24,
        "font_color": "white",
        "label_color": "black",
        "font": "FreeMono.ttf",
        "text": "head_swap: start with <image1> as the base image, keeping its lighting, environment, and background. remove the head from <image1> completely and replace it with the head from <image2>, strictly preserving the hair, eye color, nose structure from <image2>. copy the direction of the eye, head rotation, micro expressions from <image1>, high quality, sharp details, 4k",
        "direction": "down"
      }
    },
    {
      "id": 478,
      "type": "ImageResizeKJv2",
      "pos": [
        2085.495755562794,
        2053.6368005911622
      ],
      "size": [
        270,
        336
      ],
      "flags": {
        "collapsed": true
      },
      "order": 20,
      "mode": 0,
      "inputs": [
        {
          "name": "image",
          "type": "IMAGE",
          "link": 822
        },
        {
          "name": "mask",
          "shape": 7,
          "type": "MASK",
          "link": null
        },
        {
          "name": "width",
          "type": "INT",
          "widget": {
            "name": "width"
          },
          "link": 737
        },
        {
          "name": "height",
          "type": "INT",
          "widget": {
            "name": "height"
          },
          "link": 738
        }
      ],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            813
          ]
        },
        {
          "name": "width",
          "type": "INT",
          "links": []
        },
        {
          "name": "height",
          "type": "INT",
          "links": []
        },
        {
          "name": "mask",
          "type": "MASK",
          "links": null
        }
      ],
      "properties": {
        "cnr_id": "comfyui-kjnodes",
        "ver": "60cd6bc1870db94c6eeb05fbe455147a8e91c4e9",
        "Node name for S&R": "ImageResizeKJv2",
        "ue_properties": {
          "widget_ue_connectable": {},
          "input_ue_unconnectable": {},
          "version": "7.5.1"
        }
      },
      "widgets_values": [
        512,
        512,
        "lanczos",
        "resize",
        "0, 0, 0",
        "center",
        32,
        "cpu"
      ],
      "widgets_values_named": {
        "width": 512,
        "height": 512,
        "upscale_method": "lanczos",
        "keep_proportion": "resize",
        "pad_color": "0, 0, 0",
        "crop_position": "center",
        "divisible_by": 32,
        "device": "cpu"
      }
    },
    {
      "id": 519,
      "type": "PixaromaMonitor",
      "pos": [
        4643.4761888107905,
        2321.4100528070617
      ],
      "size": [
        305,
        139
      ],
      "flags": {
        "no_title": true
      },
      "order": 7,
      "mode": 0,
      "inputs": [],
      "outputs": [],
      "properties": {
        "aux_id": "pixaroma/ComfyUI-Pixaroma",
        "ver": "7a1cf573034fe14e29c1200d884531231a003e2e",
        "Node name for S&R": "PixaromaMonitor"
      },
      "color": "#1d1d1d",
      "bgcolor": "#2a2a2a"
    },
    {
      "id": 518,
      "type": "PixaromaRunTimer",
      "pos": [
        5006.753148928308,
        2363.624652313224
      ],
      "size": [
        173,
        61
      ],
      "flags": {
        "no_title": true
      },
      "order": 8,
      "mode": 0,
      "inputs": [],
      "outputs": [],
      "properties": {
        "aux_id": "pixaroma/ComfyUI-Pixaroma",
        "ver": "7a1cf573034fe14e29c1200d884531231a003e2e",
        "Node name for S&R": "PixaromaRunTimer",
        "runTimerLastMs": 110262.29999999702
      },
      "color": "#1d1d1d",
      "bgcolor": "#2a2a2a"
    },
    {
      "id": 498,
      "type": "ImageConcatMulti",
      "pos": [
        5673.37921440002,
        1838.1020984216318
      ],
      "size": [
        270,
        170
      ],
      "flags": {
        "collapsed": true
      },
      "order": 33,
      "mode": 0,
      "inputs": [
        {
          "name": "image_1",
          "type": "IMAGE,MASK",
          "link": 810
        },
        {
          "name": "image_2",
          "shape": 7,
          "type": "IMAGE,MASK",
          "link": 816
        },
        {
          "name": "image_3",
          "shape": 7,
          "type": "IMAGE,MASK",
          "link": 791
        }
      ],
      "outputs": [
        {
          "name": "output",
          "type": "IMAGE",
          "links": [
            793
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfyui-kjnodes",
        "ver": "60cd6bc1870db94c6eeb05fbe455147a8e91c4e9",
        "Node name for S&R": "ImageConcatMulti",
        "ue_properties": {
          "widget_ue_connectable": {},
          "input_ue_unconnectable": {},
          "version": "7.5.1"
        }
      },
      "widgets_values": [
        3,
        "right",
        true,
        null
      ],
      "widgets_values_named": {
        "inputcount": 3,
        "direction": "right",
        "match_image_size": true,
        "Update inputs": null
      }
    },
    {
      "id": 463,
      "type": "MarkdownNote",
      "pos": [
        1017.2388238307908,
        1731.7549997274505
      ],
      "size": [
        420,
        620
      ],
      "flags": {},
      "order": 9,
      "mode": 0,
      "inputs": [],
      "outputs": [],
      "title": "Note: Usage",
      "properties": {
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      },
      "widgets_values": [
        "## Size\nQwen Image 2.1 has native 2K (2048*2048) support for direct output.\n\n- resolution is a total pixel budget (not width or height). Aspect ratio is preserved.\n- Official default is 1024. The model supports up to 2048.\n- This template starts at 0: no resize beyond a multiple of 32.\n- Output follows image_1. Extra refs can differ in size or aspect.\n- custom_size off: canvas comes from the encode latent (image_1).\n- custom_size on: use ResolutionSelector width/height. Keep it close to the resized image_1 size, or the edit can shift.\n\n## Reference images\n- Up to 10 reference images (image_1 to image_10).\n- Mention them in the prompt as `<image1>`, `<image2>`, ...\n- image_1 is the edit target. The rest are references.\n\n## Custom settings\nIf you need custom settings, enter or unpack the subgraph to edit it. See the [Subgraph](https://docs.comfy.org/interface/features/subgraph) guide.\n\n## Parameters\n- prompt: edit instruction. Use `<image1>` ... `<image10>`.\n- negative_prompt: unused while cfg is 1.\n- cfg: keep 1 for the Qwen Image 2.1 official path. Raise it only if you use a negative prompt.\n- steps: Qwen Image 2.1 official pipeline uses about 40-50 with euler. This template starts at 25. More advanced samplers need fewer steps."
      ],
      "widgets_values_named": {
        "text": "## Size\nQwen Image 2.1 has native 2K (2048*2048) support for direct output.\n\n- resolution is a total pixel budget (not width or height). Aspect ratio is preserved.\n- Official default is 1024. The model supports up to 2048.\n- This template starts at 0: no resize beyond a multiple of 32.\n- Output follows image_1. Extra refs can differ in size or aspect.\n- custom_size off: canvas comes from the encode latent (image_1).\n- custom_size on: use ResolutionSelector width/height. Keep it close to the resized image_1 size, or the edit can shift.\n\n## Reference images\n- Up to 10 reference images (image_1 to image_10).\n- Mention them in the prompt as `<image1>`, `<image2>`, ...\n- image_1 is the edit target. The rest are references.\n\n## Custom settings\nIf you need custom settings, enter or unpack the subgraph to edit it. See the [Subgraph](https://docs.comfy.org/interface/features/subgraph) guide.\n\n## Parameters\n- prompt: edit instruction. Use `<image1>` ... `<image10>`.\n- negative_prompt: unused while cfg is 1.\n- cfg: keep 1 for the Qwen Image 2.1 official path. Raise it only if you use a negative prompt.\n- steps: Qwen Image 2.1 official pipeline uses about 40-50 with euler. This template starts at 25. More advanced samplers need fewer steps."
      },
      "color": "#222",
      "bgcolor": "#000"
    },
    {
      "id": 516,
      "type": "Note",
      "pos": [
        1020.8570340377547,
        2409.997104504801
      ],
      "size": [
        415.6683811378782,
        88
      ],
      "flags": {},
      "order": 10,
      "mode": 0,
      "inputs": [],
      "outputs": [],
      "properties": {},
      "widgets_values": [
        "To use res_2m/res_2s/deis_2m, you need res4lyf nodes installed.\n\nhttps://github.com/ClownsharkBatwing/RES4LYF"
      ],
      "widgets_values_named": {
        "text": "To use res_2m/res_2s/deis_2m, you need res4lyf nodes installed.\n\nhttps://github.com/ClownsharkBatwing/RES4LYF"
      },
      "color": "#432",
      "bgcolor": "#653"
    },
    {
      "id": 520,
      "type": "LoadImage",
      "pos": [
        2237.0713739596413,
        2196.55255720104
      ],
      "size": [
        489.2719117107954,
        506.7169146150454
      ],
      "flags": {},
      "order": 11,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            822
          ]
        },
        {
          "name": "MASK",
          "type": "MASK",
          "links": null
        }
      ],
      "title": "Head Reference",
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "LoadImage"
      },
      "widgets_values": [
        "",
        "image"
      ],
      "widgets_values_named": {
        "image": "",
        "upload": "image"
      }
    },
    {
      "id": 521,
      "type": "LoadImage",
      "pos": [
        1670.4413112887125,
        2192.3681468445216
      ],
      "size": [
        528.6018942852943,
        517.2049099682451
      ],
      "flags": {},
      "order": 12,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            823
          ]
        },
        {
          "name": "MASK",
          "type": "MASK",
          "links": null
        }
      ],
      "title": "Body Reference",
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "LoadImage"
      },
      "widgets_values": [
        "",
        "image"
      ],
      "widgets_values_named": {
        "image": "",
        "upload": "image"
      }
    },
    {
      "id": 461,
      "type": "SaveImageAdvanced",
      "pos": [
        4631.9766474460785,
        1958.87075892969
      ],
      "size": [
        534.5207875789044,
        342
      ],
      "flags": {},
      "order": 32,
      "mode": 0,
      "inputs": [
        {
          "name": "images",
          "type": "IMAGE",
          "link": 755
        }
      ],
      "outputs": [
        {
          "name": "images",
          "type": "IMAGE",
          "links": [
            791,
            826
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "SaveImageAdvanced",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      },
      "widgets_values": [
        "Qwen_image_2.1",
        "png",
        "8-bit",
        "sRGB"
      ],
      "widgets_values_named": {
        "filename_prefix": "Qwen_image_2.1",
        "format": "png",
        "format.bit_depth": "8-bit",
        "format.input_color_space": "sRGB"
      }
    },
    {
      "id": 490,
      "type": "KSampler",
      "pos": [
        4191.932024471378,
        1812.297418710113
      ],
      "size": [
        270,
        651
      ],
      "flags": {},
      "order": 30,
      "mode": 0,
      "inputs": [
        {
          "name": "model",
          "type": "MODEL",
          "link": 759
        },
        {
          "name": "positive",
          "type": "CONDITIONING",
          "link": 775
        },
        {
          "name": "negative",
          "type": "CONDITIONING",
          "link": 776
        },
        {
          "name": "latent_image",
          "type": "LATENT",
          "link": 788
        }
      ],
      "outputs": [
        {
          "name": "LATENT",
          "type": "LATENT",
          "links": [
            756
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "KSampler",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      },
      "widgets_values": [
        42,
        "fixed",
        10,
        1,
        "deis_2m",
        "simple",
        1
      ],
      "widgets_values_named": {
        "seed": 42,
        "control_after_generate": "fixed",
        "steps": 10,
        "cfg": 1,
        "sampler_name": "deis_2m",
        "scheduler": "simple",
        "denoise": 1
      },
      "color": "#223",
      "bgcolor": "#335"
    },
    {
      "id": 491,
      "type": "UNETLoader",
      "pos": [
        2818.0687099342763,
        1801.8492046478232
      ],
      "size": [
        510,
        90
      ],
      "flags": {},
      "order": 13,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "MODEL",
          "type": "MODEL",
          "links": [
            770
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "UNETLoader",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        },
        "models": [
          {
            "name": "qwen_image_2.1_int8_convrot.safetensors",
            "url": "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_int8_convrot.safetensors",
            "directory": "diffusion_models"
          }
        ]
      },
      "widgets_values": [
        "qwen_image_2.1_int8_convrot.safetensors",
        "default"
      ],
      "widgets_values_named": {
        "unet_name": "qwen_image_2.1_int8_convrot.safetensors",
        "weight_dtype": "default"
      },
      "color": "#223",
      "bgcolor": "#335"
    },
    {
      "id": 492,
      "type": "LoraLoaderModelOnly",
      "pos": [
        2821.8589049425586,
        1940.740520826475
      ],
      "size": [
        500.1102810387763,
        82
      ],
      "flags": {},
      "order": 22,
      "mode": 0,
      "inputs": [
        {
          "name": "model",
          "type": "MODEL",
          "link": 770
        }
      ],
      "outputs": [
        {
          "name": "MODEL",
          "type": "MODEL",
          "links": [
            800
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "LoraLoaderModelOnly",
        "ue_properties": {
          "widget_ue_connectable": {},
          "input_ue_unconnectable": {},
          "version": "7.5.1"
        }
      },
      "widgets_values": [
        "p_qwen_image_2.1_8step_v0.1.safetensors",
        0.75
      ],
      "widgets_values_named": {
        "lora_name": "p_qwen_image_2.1_8step_v0.1.safetensors",
        "strength_model": 0.75
      },
      "color": "#2a363b",
      "bgcolor": "#3f5159"
    },
    {
      "id": 493,
      "type": "LoraLoaderModelOnly",
      "pos": [
        2826.6732322753633,
        2076.367252387245
      ],
      "size": [
        500.1102810387763,
        82
      ],
      "flags": {},
      "order": 28,
      "mode": 0,
      "inputs": [
        {
          "name": "model",
          "type": "MODEL",
          "link": 800
        }
      ],
      "outputs": [
        {
          "name": "MODEL",
          "type": "MODEL",
          "links": [
            799
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "LoraLoaderModelOnly",
        "ue_properties": {
          "widget_ue_connectable": {},
          "input_ue_unconnectable": {},
          "version": "7.5.1"
        }
      },
      "widgets_values": [
        "bfs_head_v1_qwen_2.1.safetensors",
        1
      ],
      "widgets_values_named": {
        "lora_name": "bfs_head_v1_qwen_2.1.safetensors",
        "strength_model": 1
      },
      "color": "#232",
      "bgcolor": "#353"
    },
    {
      "id": 484,
      "type": "CLIPLoader",
      "pos": [
        2821.102638566112,
        2216.4738712583617
      ],
      "size": [
        510,
        120
      ],
      "flags": {},
      "order": 14,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "CLIP",
          "type": "CLIP",
          "links": [
            772
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "CLIPLoader",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        },
        "models": [
          {
            "name": "qwen3vl_8b_int8_convrot.safetensors",
            "url": "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors",
            "directory": "text_encoders"
          }
        ]
      },
      "widgets_values": [
        "qwen3vl_8b_int8_convrot.safetensors",
        "qwen_image",
        "default"
      ],
      "widgets_values_named": {
        "clip_name": "qwen3vl_8b_int8_convrot.safetensors",
        "type": "qwen_image",
        "device": "default"
      },
      "color": "#432",
      "bgcolor": "#653"
    },
    {
      "id": 485,
      "type": "VAELoader",
      "pos": [
        2819.6605392050487,
        2397.7265795645244
      ],
      "size": [
        510,
        70
      ],
      "flags": {},
      "order": 15,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "VAE",
          "type": "VAE",
          "links": [
            754,
            774
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "VAELoader",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        },
        "models": [
          {
            "name": "qwen_image_2.1_vae_bf16.safetensors",
            "url": "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors",
            "directory": "vae"
          }
        ]
      },
      "widgets_values": [
        "qwen_image_2.1_vae_bf16.safetensors"
      ],
      "widgets_values_named": {
        "vae_name": "qwen_image_2.1_vae_bf16.safetensors"
      },
      "color": "#322",
      "bgcolor": "#533"
    },
    {
      "id": 506,
      "type": "GetNode",
      "pos": [
        3368.122486466318,
        1780.240916087101
      ],
      "size": [
        210,
        60
      ],
      "flags": {
        "collapsed": true
      },
      "order": 16,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            807
          ]
        }
      ],
      "title": "Get_body_reference",
      "properties": {
        "Node name for S&R": "GetNode",
        "aux_id": "kijai/ComfyUI-KJNodes"
      },
      "widgets_values": [
        "body_reference"
      ],
      "widgets_values_named": {
        "Constant": "body_reference"
      },
      "color": "#2a363b",
      "bgcolor": "#3f5159"
    },
    {
      "id": 510,
      "type": "GetNode",
      "pos": [
        3368.797648894977,
        1823.9783986126224
      ],
      "size": [
        210,
        60
      ],
      "flags": {
        "collapsed": true
      },
      "order": 17,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "links": [
            814
          ]
        }
      ],
      "title": "Get_head_reference",
      "properties": {
        "Node name for S&R": "GetNode",
        "aux_id": "kijai/ComfyUI-KJNodes"
      },
      "widgets_values": [
        "head_reference"
      ],
      "widgets_values_named": {
        "Constant": "head_reference"
      },
      "color": "#2a363b",
      "bgcolor": "#3f5159"
    },
    {
      "id": 495,
      "type": "QwenImage21Cache",
      "pos": [
        4110.576736180572,
        2538.1286997147186
      ],
      "size": [
        270,
        90
      ],
      "flags": {},
      "order": 29,
      "mode": 0,
      "inputs": [
        {
          "name": "model",
          "type": "MODEL",
          "link": 799
        }
      ],
      "outputs": [
        {
          "name": "MODEL",
          "type": "MODEL",
          "links": [
            759
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "QwenImage21Cache",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      },
      "widgets_values": [
        "auto",
        "default"
      ],
      "widgets_values_named": {
        "device": "auto",
        "dtype": "default"
      }
    },
    {
      "id": 496,
      "type": "TextEncodeQwenImage21",
      "pos": [
        3384.3207693337667,
        1885.26412706718
      ],
      "size": [
        664.4860444565738,
        596.5811223479423
      ],
      "flags": {},
      "order": 23,
      "mode": 0,
      "inputs": [
        {
          "name": "clip",
          "type": "CLIP",
          "link": 772
        },
        {
          "name": "images.image_1",
          "shape": 7,
          "type": "IMAGE",
          "link": 807
        },
        {
          "name": "images.image_2",
          "shape": 7,
          "type": "IMAGE",
          "link": 814
        },
        {
          "name": "images.image_3",
          "shape": 7,
          "type": "IMAGE",
          "link": null
        },
        {
          "name": "vae",
          "shape": 7,
          "type": "VAE",
          "link": 774
        }
      ],
      "outputs": [
        {
          "name": "positive",
          "type": "CONDITIONING",
          "links": [
            775
          ]
        },
        {
          "name": "negative",
          "type": "CONDITIONING",
          "links": [
            776
          ]
        },
        {
          "name": "latent",
          "type": "LATENT",
          "links": []
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "TextEncodeQwenImage21",
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      },
      "widgets_values": [
        "head_swap: start with <image1> as the base image, keeping its lighting, environment, and background. remove the head from <image1> completely and replace it with the head from <image2>, strictly preserving the hair, eye color, nose structure from <image2>. copy the direction of the eye, head rotation, micro expressions from <image1>, high quality, sharp details, 4k",
        "",
        0
      ],
      "widgets_values_named": {
        "prompt": "head_swap: start with <image1> as the base image, keeping its lighting, environment, and background. remove the head from <image1> completely and replace it with the head from <image2>, strictly preserving the hair, eye color, nose structure from <image2>. copy the direction of the eye, head rotation, micro expressions from <image1>, high quality, sharp details, 4k",
        "negative_prompt": "",
        "resolution": 0
      }
    },
    {
      "id": 523,
      "type": "Image Comparer (rgthree)",
      "pos": [
        6018.05060694634,
        2092.605824441647
      ],
      "size": [
        646.6657461693152,
        617.2419659690831
      ],
      "flags": {},
      "order": 34,
      "mode": 0,
      "inputs": [
        {
          "dir": 3,
          "name": "image_a",
          "type": "IMAGE",
          "link": 825
        },
        {
          "dir": 3,
          "name": "image_b",
          "type": "IMAGE",
          "link": 826
        }
      ],
      "outputs": [
        {
          "dir": 4,
          "name": "images",
          "shape": 3,
          "type": "IMAGE",
          "links": null
        }
      ],
      "properties": {
        "cnr_id": "rgthree-comfy",
        "ver": "2c5342a8cb0eaecaabf61435a5f37dd594c510ba",
        "comparer_mode": "Slide"
      },
      "widgets_values": [
        [
          {
            "name": "A",
            "selected": true,
            "url": "/api/view?filename=rgthree.compare._temp_ptpjy_00007_.png&type=temp&subfolder=&rand=0.9761825979213351"
          },
          {
            "name": "B",
            "selected": true,
            "url": "/api/view?filename=rgthree.compare._temp_ptpjy_00008_.png&type=temp&subfolder=&rand=0.5228876655651826"
          }
        ]
      ],
      "widgets_values_named": {
        "rgthree_comparer": {
          "images": [
            {
              "name": "A",
              "selected": true,
              "url": "/api/view?filename=rgthree.compare._temp_ptpjy_00007_.png&type=temp&subfolder=&rand=0.9761825979213351",
              "img": {}
            },
            {
              "name": "B",
              "selected": true,
              "url": "/api/view?filename=rgthree.compare._temp_ptpjy_00008_.png&type=temp&subfolder=&rand=0.5228876655651826",
              "img": {}
            }
          ]
        }
      },
      "color": "#223",
      "bgcolor": "#335"
    },
    {
      "id": 522,
      "type": "PreviewImage",
      "pos": [
        5206.456128219506,
        2198.2008847630705
      ],
      "size": [
        770.6633818721966,
        452.6249585153489
      ],
      "flags": {},
      "order": 36,
      "mode": 0,
      "inputs": [
        {
          "name": "images",
          "type": "IMAGE",
          "link": 824
        }
      ],
      "outputs": [
        {
          "name": "images",
          "type": "IMAGE",
          "links": [
            827
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "PreviewImage"
      },
      "widgets_values": [],
      "widgets_values_named": {},
      "color": "#233",
      "bgcolor": "#355"
    },
    {
      "id": 524,
      "type": "SaveImage",
      "pos": [
        5231.749310677649,
        2717.1859561182305
      ],
      "size": [
        210,
        58
      ],
      "flags": {
        "collapsed": true
      },
      "order": 37,
      "mode": 0,
      "inputs": [
        {
          "name": "images",
          "type": "IMAGE",
          "link": 827
        }
      ],
      "outputs": [
        {
          "name": "images",
          "type": "IMAGE",
          "links": null
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.37.1",
        "Node name for S&R": "SaveImage"
      },
      "widgets_values": [
        "ComfyUI"
      ],
      "widgets_values_named": {
        "filename_prefix": "ComfyUI"
      }
    },
    {
      "id": 476,
      "type": "MarkdownNote",
      "pos": [
        572.0659855390135,
        1726.582161435673
      ],
      "size": [
        420,
        768.023763555555
      ],
      "flags": {},
      "order": 18,
      "mode": 0,
      "inputs": [],
      "outputs": [],
      "title": "Note: Model links",
      "properties": {
        "ue_properties": {
          "widget_ue_connectable": {},
          "version": "7.5.1",
          "input_ue_unconnectable": {}
        }
      },
      "widgets_values": [
        "\n## Model Links\n\n- [Hugging Face:Comfy-Org/Qwen-Image-2.1](https://huggingface.co/Comfy-Org/Qwen-Image-2.1)\n- [ModelScope:Comfy-Org/Qwen-Image-2.1](https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1)\n\n**diffusion_models**\n\n- [qwen_image_2.1_bf16.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_bf16.safetensors)\n- [qwen_image_2.1_int8_convrot.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_int8_convrot.safetensors)\n\n**text_encoders**\n\n- [qwen3vl_8b_bf16.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_bf16.safetensors)\n- [qwen3vl_8b_int8_convrot.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors) \n\n**vae**\n\n- [qwen_image_2.1_vae_bf16.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors)\n\n**loras**\n\n- [bfs_head_v1_qwen_2.1.safetensors](https://huggingface.co/Alissonerdx/BFS-Best-Face-Swap/blob/main/bfs_head_v1_qwen_2.1.safetensors)\n\n- [p_qwen_image_2.1_5step_v0.1.safetensors](https://huggingface.co/PrunaAI/Pruna-Qwen-Image-2.1/blob/main/p_qwen_image_2.1_5step_v0.1.safetensors)\n\n- [p_qwen_image_2.1_8step_v0.1.safetensors](https://huggingface.co/PrunaAI/Pruna-Qwen-Image-2.1/blob/main/p_qwen_image_2.1_8step_v0.1.safetensors)\n\n## Model Storage Location\n\n```\n\ud83d\udcc2 ComfyUI/\n\u251c\u2500\u2500 \ud83d\udcc2 models/\n\u2502   \u251c\u2500\u2500 \ud83d\udcc2 diffusion_models/\n\u2502   \u2502   \u251c\u2500\u2500 qwen_image_2.1_bf16.safetensors\n\u2502   \u2502   \u2514\u2500\u2500 qwen_image_2.1_int8_convrot.safetensors\n\u2502   \u251c\u2500\u2500 \ud83d\udcc2 text_encoders/\n\u2502   \u2502   \u251c\u2500\u2500 qwen3vl_8b_bf16.safetensors\n\u2502   \u2502   \u2514\u2500\u2500 qwen3vl_8b_int8_convrot.safetensors\n\u2502   \u2514\u2500\u2500 \ud83d\udcc2 vae/\n\u2502       \u2514\u2500\u2500 qwen_image_2.1_vae_bf16.safetensors\n```\n\n## Report Issue\n\nNote: Please update ComfyUI first ([guide](https://docs.comfy.org/installation/update_comfyui)) and prepare required models. Desktop/Cloud updates follow stable releases, so some nightly-supported models may not be available yet.\n\n- Cannot run / runtime errors: [ComfyUI/issues](https://github.com/comfyanonymous/ComfyUI/issues)\n- UI / frontend issues: [ComfyUI_frontend/issues](https://github.com/Comfy-Org/ComfyUI_frontend/issues)\n- Workflow issues: [workflow_templates/issues](https://github.com/Comfy-Org/workflow_templates/issues)\n"
      ],
      "widgets_values_named": {
        "text": "\n## Model Links\n\n- [Hugging Face:Comfy-Org/Qwen-Image-2.1](https://huggingface.co/Comfy-Org/Qwen-Image-2.1)\n- [ModelScope:Comfy-Org/Qwen-Image-2.1](https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1)\n\n**diffusion_models**\n\n- [qwen_image_2.1_bf16.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_bf16.safetensors)\n- [qwen_image_2.1_int8_convrot.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_int8_convrot.safetensors)\n\n**text_encoders**\n\n- [qwen3vl_8b_bf16.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_bf16.safetensors)\n- [qwen3vl_8b_int8_convrot.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors) \n\n**vae**\n\n- [qwen_image_2.1_vae_bf16.safetensors](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors)\n\n**loras**\n\n- [bfs_head_v1_qwen_2.1.safetensors](https://huggingface.co/Alissonerdx/BFS-Best-Face-Swap/blob/main/bfs_head_v1_qwen_2.1.safetensors)\n\n- [p_qwen_image_2.1_5step_v0.1.safetensors](https://huggingface.co/PrunaAI/Pruna-Qwen-Image-2.1/blob/main/p_qwen_image_2.1_5step_v0.1.safetensors)\n\n- [p_qwen_image_2.1_8step_v0.1.safetensors](https://huggingface.co/PrunaAI/Pruna-Qwen-Image-2.1/blob/main/p_qwen_image_2.1_8step_v0.1.safetensors)\n\n## Model Storage Location\n\n```\n\ud83d\udcc2 ComfyUI/\n\u251c\u2500\u2500 \ud83d\udcc2 models/\n\u2502   \u251c\u2500\u2500 \ud83d\udcc2 diffusion_models/\n\u2502   \u2502   \u251c\u2500\u2500 qwen_image_2.1_bf16.safetensors\n\u2502   \u2502   \u2514\u2500\u2500 qwen_image_2.1_int8_convrot.safetensors\n\u2502   \u251c\u2500\u2500 \ud83d\udcc2 text_encoders/\n\u2502   \u2502   \u251c\u2500\u2500 qwen3vl_8b_bf16.safetensors\n\u2502   \u2502   \u2514\u2500\u2500 qwen3vl_8b_int8_convrot.safetensors\n\u2502   \u2514\u2500\u2500 \ud83d\udcc2 vae/\n\u2502       \u2514\u2500\u2500 qwen_image_2.1_vae_bf16.safetensors\n```\n\n## Report Issue\n\nNote: Please update ComfyUI first ([guide](https://docs.comfy.org/installation/update_comfyui)) and prepare required models. Desktop/Cloud updates follow stable releases, so some nightly-supported models may not be available yet.\n\n- Cannot run / runtime errors: [ComfyUI/issues](https://github.com/comfyanonymous/ComfyUI/issues)\n- UI / frontend issues: [ComfyUI_frontend/issues](https://github.com/Comfy-Org/ComfyUI_frontend/issues)\n- Workflow issues: [workflow_templates/issues](https://github.com/Comfy-Org/workflow_templates/issues)\n"
      },
      "color": "#222",
      "bgcolor": "#000"
    }
  ],
  "links": [
    [
      735,
      13,
      0,
      477,
      2,
      "INT"
    ],
    [
      736,
      13,
      1,
      477,
      3,
      "INT"
    ],
    [
      737,
      13,
      0,
      478,
      2,
      "INT"
    ],
    [
      738,
      13,
      1,
      478,
      3,
      "INT"
    ],
    [
      754,
      485,
      0,
      487,
      1,
      "VAE"
    ],
    [
      755,
      487,
      0,
      461,
      0,
      "IMAGE"
    ],
    [
      756,
      490,
      0,
      487,
      0,
      "LATENT"
    ],
    [
      759,
      495,
      0,
      490,
      0,
      "MODEL"
    ],
    [
      770,
      491,
      0,
      492,
      0,
      "MODEL"
    ],
    [
      772,
      484,
      0,
      496,
      0,
      "CLIP"
    ],
    [
      774,
      485,
      0,
      496,
      4,
      "VAE"
    ],
    [
      775,
      496,
      0,
      490,
      1,
      "CONDITIONING"
    ],
    [
      776,
      496,
      1,
      490,
      2,
      "CONDITIONING"
    ],
    [
      788,
      486,
      0,
      490,
      3,
      "LATENT"
    ],
    [
      791,
      461,
      0,
      498,
      2,
      "IMAGE"
    ],
    [
      793,
      498,
      0,
      499,
      0,
      "IMAGE"
    ],
    [
      799,
      493,
      0,
      495,
      0,
      "MODEL"
    ],
    [
      800,
      492,
      0,
      493,
      0,
      "MODEL"
    ],
    [
      805,
      477,
      0,
      505,
      0,
      "IMAGE"
    ],
    [
      807,
      506,
      0,
      496,
      1,
      "IMAGE"
    ],
    [
      810,
      508,
      0,
      498,
      0,
      "IMAGE"
    ],
    [
      813,
      478,
      0,
      509,
      0,
      "IMAGE"
    ],
    [
      814,
      510,
      0,
      496,
      2,
      "IMAGE"
    ],
    [
      816,
      511,
      0,
      498,
      1,
      "IMAGE"
    ],
    [
      817,
      477,
      1,
      512,
      0,
      "INT"
    ],
    [
      819,
      477,
      2,
      513,
      0,
      "INT"
    ],
    [
      820,
      514,
      0,
      486,
      0,
      "INT"
    ],
    [
      821,
      515,
      0,
      486,
      1,
      "INT"
    ],
    [
      822,
      520,
      0,
      478,
      0,
      "IMAGE"
    ],
    [
      823,
      521,
      0,
      477,
      0,
      "IMAGE"
    ],
    [
      824,
      499,
      0,
      522,
      0,
      "IMAGE"
    ],
    [
      825,
      507,
      0,
      523,
      0,
      "IMAGE"
    ],
    [
      826,
      461,
      0,
      523,
      1,
      "IMAGE"
    ],
    [
      827,
      522,
      0,
      524,
      0,
      "IMAGE"
    ]
  ],
  "groups": [
    {
      "id": 34,
      "title": "Models",
      "bounding": [
        2811.1026385661135,
        1711.4116754047639,
        527.6032308619097,
        1055.3236429341985
      ],
      "color": "#3f789e",
      "flags": {}
    },
    {
      "id": 35,
      "title": "Image Size",
      "bounding": [
        3360.698035328163,
        2518.8710926928547,
        708.5073852107066,
        236.56396025295726
      ],
      "color": "#3f789e",
      "flags": {}
    },
    {
      "id": 36,
      "title": "Conditioning",
      "bounding": [
        3356.6095399874143,
        1711.8731472003014,
        713.9595218151089,
        776.242869109346
      ],
      "color": "#3f789e",
      "flags": {}
    },
    {
      "id": 37,
      "title": "Sampling",
      "bounding": [
        4084.8645997605254,
        1712.7816697977712,
        476.5224553976277,
        1042.797314759204
      ],
      "color": "#3f789e",
      "flags": {}
    },
    {
      "id": 38,
      "title": "Inputs",
      "bounding": [
        1500.6640222320157,
        1702.0791000952963,
        1291.7247087470676,
        1066.4338324976673
      ],
      "color": "#3f789e",
      "flags": {}
    },
    {
      "id": 39,
      "title": "Results",
      "bounding": [
        4570.852776304226,
        1714.1637462467522,
        2125.5314521123983,
        1040.6194610216603
      ],
      "color": "#3f789e",
      "flags": {}
    }
  ],
  "config": {},
  "extra": {
    "ds": {
      "scale": 0.5386321110806304,
      "offset": [
        -3327.4297832677976,
        -1203.7541797397037
      ]
    },
    "frontendVersion": "1.52.7",
    "VHS_latentpreview": false,
    "VHS_latentpreviewrate": 0,
    "VHS_MetadataImage": true,
    "VHS_KeepIntermediate": true,
    "ue_links": [],
    "links_added_by_ue": []
  },
  "version": 0.4,
  "seed_widgets": {
    "490": 0
  }
}
JSON

cp "$COMFY_DIR/user/default/workflows/Qwen2.1-BFS-Head-V1-Workflow.json" /workspace/Qwen2.1-BFS-Head-V1-Workflow.json || true

say "Writing summary"
cat > /workspace/QWEN_BFS_SETUP_DONE.txt <<EOF
Qwen BFS setup finished successfully at $(date)
ComfyUI: $COMFY_DIR
Workflow: $COMFY_DIR/user/default/workflows/Qwen2.1-BFS-Head-V1-Workflow.json
Required custom nodes installed:
- ComfyUI-KJNodes
- comfyui-pixaroma
- rgthree-comfy
- RES4LYF
Models:
- qwen_image_2.1_int8_convrot.safetensors
- qwen3vl_8b_int8_convrot.safetensors
- qwen_image_2.1_vae_bf16.safetensors
LoRAs:
- bfs_head_v1_qwen_2.1.safetensors
- p_qwen_image_2.1_8step_v0.1.safetensors
Usage:
- image1 = Body / target reference
- image2 = Head reference
EOF

say "Quick verification"
ls -lh "$COMFY_DIR/models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors"
ls -lh "$COMFY_DIR/models/text_encoders/qwen3vl_8b_int8_convrot.safetensors"
ls -lh "$COMFY_DIR/models/vae/qwen_image_2.1_vae_bf16.safetensors"
ls -lh "$COMFY_DIR/models/loras/bfs_head_v1_qwen_2.1.safetensors"
ls -lh "$COMFY_DIR/models/loras/p_qwen_image_2.1_8step_v0.1.safetensors"
ls -lh "$COMFY_DIR/user/default/workflows/Qwen2.1-BFS-Head-V1-Workflow.json"

say "Done"
echo "If ComfyUI is already open, hard refresh the page or restart ComfyUI."
echo "Workflow name: Qwen2.1-BFS-Head-V1-Workflow"
echo "Status file: /workspace/QWEN_BFS_SETUP_DONE.txt"
echo "Log file: $LOGFILE"
