#!/usr/bin/env bash
set -euo pipefail
if [[ "${NV_STACK_DEBUG:-0}" == "1" ]]; then
  set -o errtrace
  trap 'echo "ERROR: ${PROG}: command failed at line ${LINENO}" >&2' ERR
fi

PROG="$(basename "$0")"

usage() {
  cat <<'EOF'
Usage:
  read_nv_release_stack.sh <NV_RELEASE> [--env|--json|--pretty|--key <name>|--strict]
  read_nv_release_stack.sh --selftest

Examples:
  ./read_nv_release_stack.sh 24.08 --env
  ./read_nv_release_stack.sh 24.08 --json
  ./read_nv_release_stack.sh 24.08 --pretty
  ./read_nv_release_stack.sh 24.08 --key ubuntu_version
  ./read_nv_release_stack.sh 24.08 --strict --env

Notes:
  - NV_RELEASE format: NN.NN (e.g., 24.08)
  - Fetches and parses NVIDIA release notes pages:
      * PyTorch release notes
      * TensorFlow release notes
      * Triton Inference Server release notes
      * Triton Release Compatibility Matrix (vLLM + TensorRT-LLM containers)

Requirements:
  - curl (preferred) or wget
  - sed, awk, tr (standard on Ubuntu)

Output:
  --env:    key=value lines (safe for GitHub Actions $GITHUB_OUTPUT)
  --json:   flat JSON object (string values; empty if unknown)
  --pretty: human-friendly key: value lines
  --key:    print a single key value (empty string if unknown)

EOF
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

fetch_url() {
  local url="$1"
  if need_cmd curl; then
    curl -fsSL "$url"
  elif need_cmd wget; then
    wget -qO- "$url"
  else
    echo "ERROR: need curl or wget" >&2
    exit 2
  fi
}

# Lightweight HTML->text: strip tags + collapse whitespace.
html_to_text() {
  awk '
    BEGIN { in_script=0; in_style=0 }
    {
      line=$0
      if (line ~ /<script[^>]*>/) in_script=1
      if (line ~ /<style[^>]*>/)  in_style=1

      if (!in_script && !in_style) {
        gsub(/<[^>]*>/, " ", line)
        print line
      }

      if (in_script && line ~ /<\/script>/) in_script=0
      if (in_style  && line ~ /<\/style>/)  in_style=0
    }
  ' \
  | tr '\r\n' '  ' \
  | sed -E 's/[[:space:]]+/ /g'
}

# First capture group match from a single-line text stream using sed -E.
# The pattern MUST contain exactly one capture group (...).
sed_cap1() {
  local pattern="$1"
  sed -nE "s~.*${pattern}.*~\1~p" | head -n1 || true
}

# First capture group match with TWO capture groups; prints "g1|g2".
sed_cap2() {
  local pattern="$1"
  sed -nE "s~.*${pattern}.*~\1|\2~p" | head -n1 || true
}

# Extract multiple known component versions from a flattened release-notes text.
# Prints key=value per line.
extract_components() {
  local prefix="$1"
  local s
  s="$(cat)"

  emit() {
    local k="$1" v="$2"
    if [[ -n "$v" ]]; then
      printf '%s%s=%s
' "$prefix" "$k" "$v"
    fi
    return 0
  }

  # Ubuntu + Python (common bullet format)
  local up
  up="$(printf '%s' "$s" | sed_cap2 'Ubuntu ([0-9]{2}\.[0-9]{2}) including Python ([0-9][0-9.]+)')"
  if [[ -n "$up" ]]; then
    emit "ubuntu_version" "${up%%|*}"
    emit "python_version" "${up#*|}"
  else
    emit "ubuntu_version" "$(printf '%s' "$s" | sed_cap1 'Ubuntu ([0-9]{2}\.[0-9]{2})')"
    emit "python_version" "$(printf '%s' "$s" | sed_cap1 'Python ([0-9][0-9.]+)')"
  fi

  emit "cuda_version" "$(printf '%s' "$s" | sed_cap1 'NVIDIA CUDA ([0-9][0-9.]+)')"
  emit "cublas_version" "$(printf '%s' "$s" | sed_cap1 'cuBLAS ([0-9][0-9.]+)')"
  # cuDNN appears as "NVIDIA cuDNN" or just "cuDNN"
  emit "cudnn_version" "$(printf '%s' "$s" | sed_cap1 'cuDNN ([0-9][0-9.]+)')"
  emit "nccl_version" "$(printf '%s' "$s" | sed_cap1 'NVIDIA NCCL ([0-9][0-9.]+)')"
  emit "cutensor_version" "$(printf '%s' "$s" | sed_cap1 'cuTENSOR ([0-9][0-9.]+)')"

  # TensorRT sometimes includes ™; match any non-digit separator before version
  emit "tensorrt_version" "$(printf '%s' "$s" | sed_cap1 'TensorRT[^-0-9]*([0-9][0-9.]+)')"

  emit "rapids_version" "$(printf '%s' "$s" | sed_cap1 'RAPIDS[^0-9]*([0-9][0-9.]+)')"
  emit "horovod_version" "$(printf '%s' "$s" | sed_cap1 'Horovod ([0-9][0-9.]+)')"

  emit "openmpi_version" "$(printf '%s' "$s" | sed_cap1 'OpenMPI ([0-9][0-9.]+)')"
  emit "openucx_version" "$(printf '%s' "$s" | sed_cap1 'OpenUCX ([0-9][0-9.]+)')"
  emit "hpcx_version" "$(printf '%s' "$s" | sed_cap1 'HPC-X ([0-9][0-9.]+)')"
  emit "gdrcopy_version" "$(printf '%s' "$s" | sed_cap1 'GDRCopy ([0-9][0-9.]+)')"
  emit "sharp_version" "$(printf '%s' "$s" | sed_cap1 'SHARP ([0-9][0-9.]+)')"
  emit "rdma_core_version" "$(printf '%s' "$s" | sed_cap1 'rdma-core ([0-9][0-9.]+)')"

  emit "tensorboard_version" "$(printf '%s' "$s" | sed_cap1 'TensorBoard ([0-9][0-9.]+)')"
  emit "nsight_compute_version" "$(printf '%s' "$s" | sed_cap1 'Nsight Compute ([0-9][0-9.]+)')"
  emit "nsight_systems_version" "$(printf '%s' "$s" | sed_cap1 'Nsight Systems ([0-9][0-9.]+)')"

  emit "onnxruntime_version" "$(printf '%s' "$s" | sed_cap1 'ONNX Runtime ([0-9][0-9.]+)')"
  # OpenVINO often shows as "OpenVINO 2024.0.0"
  emit "openvino_version" "$(printf '%s' "$s" | sed_cap1 'OpenVINO[^0-9]*([0-9][0-9.]+)')"
  emit "dcgm_version" "$(printf '%s' "$s" | sed_cap1 'DCGM ([0-9][0-9.]+)')"
  emit "nvimagecodec_version" "$(printf '%s' "$s" | sed_cap1 'nvImageCodec ([0-9][0-9.]+)')"
  emit "dali_version" "$(printf '%s' "$s" | sed_cap1 'DALI[^0-9]*([0-9][0-9.]+)')"

  # TensorRT-LLM: "version release/0.12.0" or "version 0.12.0"
  emit "tensorrtllm_version" "$(printf '%s' "$s" | sed -nE 's~.*TensorRT-LLM[^v]*version (release/)?([0-9][0-9.]+).*~\2~p' | head -n1)"

  # vLLM: in Triton notes it can be "vLLM ... version 0.5.3 post 1"
  emit "vllm_version" "$(printf '%s' "$s" | sed -nE 's~.*vLLM[^v]*version ([0-9][0-9.]+( post [0-9]+)?).*~\1~p' | head -n1)"

  # Driver requirements: "requires NVIDIA Driver release 560 or later"
  emit "min_driver_branch" "$(printf '%s' "$s" | sed_cap1 'requires NVIDIA Driver[^0-9]*([0-9]{3})')"
}

# Parse Triton compatibility matrix for container variants (vllm-python-py3, trtllm-python-py3).
# Returns key=value lines (no prefix).
extract_triton_matrix() {
  local rel="$1"
  local s="$2"

  # vLLM row: capture Python, vLLM, CUDA, driver, size
  local vrow
  vrow="$(printf '%s' "$s" | sed -nE "s~.* ${rel} nvcr\.io/nvidia/tritonserver:${rel}-vllm-python-py3 Python ([0-9][0-9.]+) ([0-9][0-9A-Za-z+._-]*( post ?[0-9]+)?) ([0-9][0-9.]+) ([0-9][0-9.]+) ([0-9.]+ ?G(B)?).*~\\1|\\2|\\3|\\4|\\5~p" | head -n1)" || true
  if [[ -n "$vrow" ]]; then
    IFS='|' read -r v_py v_vllm v_cuda v_drv v_size <<<"$vrow"
    printf '%s\n' \
      "triton_matrix_vllm_tag=nvcr.io/nvidia/tritonserver:${rel}-vllm-python-py3" \
      "triton_matrix_vllm_python_version=${v_py}" \
      "triton_matrix_vllm_version=${v_vllm}" \
      "triton_matrix_vllm_cuda_version=${v_cuda}" \
      "triton_matrix_vllm_driver_version=${v_drv}" \
      "triton_matrix_vllm_size=${v_size}"
  fi

  # TensorRT-LLM row: capture Python, Torch, TensorRT, TensorRT-LLM, CUDA, driver, size
  local trow
  trow="$(printf '%s' "$s" | sed -nE "s~.* ${rel} nvcr\.io/nvidia/tritonserver:${rel}-trtllm-python-py3 Python ([0-9][0-9.]+) ([^ ]+) ([0-9][0-9.]+) ([0-9][0-9.]+) ([0-9][0-9.]+) ([0-9][0-9.]+) ([0-9.]+ ?G(B)?).*~\\1|\\2|\\3|\\4|\\5|\\6|\\7~p" | head -n1)" || true
  if [[ -n "$trow" ]]; then
    IFS='|' read -r t_py t_torch t_trt t_trtllm t_cuda t_drv t_size <<<"$trow"
    printf '%s\n' \
      "triton_matrix_trtllm_tag=nvcr.io/nvidia/tritonserver:${rel}-trtllm-python-py3" \
      "triton_matrix_trtllm_python_version=${t_py}" \
      "triton_matrix_trtllm_torch_version=${t_torch}" \
      "triton_matrix_trtllm_tensorrt_version=${t_trt}" \
      "triton_matrix_trtllm_tensorrtllm_version=${t_trtllm}" \
      "triton_matrix_trtllm_cuda_version=${t_cuda}" \
      "triton_matrix_trtllm_driver_version=${t_drv}" \
      "triton_matrix_trtllm_size=${t_size}"
  fi
}

validate_release() {
  local r="$1"
  if [[ ! "$r" =~ ^[0-9]{2}\.[0-9]{2}$ ]]; then
    echo "ERROR: NV_RELEASE must be NN.NN (e.g., 24.08); got '$r'" >&2
    exit 1
  fi
}

url_for_dlfw() {
  local framework="$1" rel_dash="$2"
  case "$framework" in
    pytorch)    echo "https://docs.nvidia.com/deeplearning/frameworks/pytorch-release-notes/rel-${rel_dash}.html" ;;
    tensorflow) echo "https://docs.nvidia.com/deeplearning/frameworks/tensorflow-release-notes/rel-${rel_dash}.html" ;;
    *) echo ""; return 1 ;;
  esac
}

url_for_triton_rel() {
  local rel_dash="$1"
  echo "https://docs.nvidia.com/deeplearning/triton-inference-server/release-notes/rel-${rel_dash}.html"
}

url_triton_matrix() {
  echo "https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/introduction/compatibility.html"
}

# Merge key/value streams; later entries win.
kv_merge() {
  awk -F= '
    NF>=2{
      k=$1
      v=substr($0, index($0,"=")+1)
      data[k]=v
      order[++n]=k
    }
    END{
      for(i=1;i<=n;i++){
        k=order[i]
        if(!printed[k]){
          print k "=" data[k]
          printed[k]=1
        }
      }
    }
  '
}

kv_to_json() {
  awk -F= '
    function esc(s){
      gsub(/\\/,"\\\\",s)
      gsub(/"/,"\\\"",s)
      gsub(/\t/,"\\t",s)
      gsub(/\r/,"\\r",s)
      gsub(/\n/,"\\n",s)
      return s
    }
    BEGIN{ first=1; printf "{" }
    NF>=2{
      k=$1
      v=substr($0, index($0,"=")+1)
      if(!first) printf ","
      first=0
      printf "\"%s\":\"%s\"", esc(k), esc(v)
    }
    END{ printf "}\n" }
  '
}

kv_pretty() { awk -F= 'NF>=2{ k=$1; v=substr($0, index($0,"=")+1); printf "%-44s %s\n", k":", v }'; }
kv_get() { local key="$1"; awk -F= -v k="$key" 'NF>=2 && $1==k {print substr($0, index($0,"=")+1); exit 0}'; }

assert_eq() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" != "$want" ]]; then
    echo "SELFTEST FAIL: $name: got '$got' want '$want'" >&2
    exit 10
  fi
}

selftest() {
  local triton_fixture='... Ubuntu 22.04 including Python 3.10 NVIDIA CUDA 12.6 NVIDIA cuBLAS 12.6.0.22 cuDNN 9.3.0.75 NVIDIA NCCL 2.22.3 NVIDIA TensorRT 10.3.0.26 OpenUCX 1.15.0 GDRCopy 2.3 NVIDIA HPC-X 2.19 OpenMPI 4.1.7 nvImageCodec 0.2.0.7 ONNX Runtime 1.18.1 OpenVINO 2024.0.0 DCGM 3.2.6 TensorRT-LLM version release/0.12.0 vLLM version 0.5.3 post 1 ... requires NVIDIA Driver release 560 or later ...'
  local tf_fixture='... Ubuntu 22.04 including Python 3.10.6 NVIDIA CUDA 12.6 NVIDIA cuBLAS 12.6.0.22 cuTENSOR 2.0.2.5 NVIDIA cuDNN 9.3.0.75 NVIDIA NCCL 2.22.3 NVIDIA RAPIDS 24.06 Horovod 0.28.1 OpenMPI 4.1.7 OpenUCX 1.15.0 SHARP 3.0.2 GDRCopy 2.3 NVIDIA HPC-X 2.19 TensorBoard 2.16.2 rdma-core 39.0 NVIDIA TensorRT 10.3.0.26 NVIDIA DALI 1.40 ...'
  local matrix_fixture='... Container Name: vllm-python-py3 ... 24.08 nvcr.io/nvidia/tritonserver:24.08-vllm-python-py3 Python 3.10.12 0.5.3post1.nv24.08.cu126 12.6.0.022 560.35.03 8.1G ... Container Name: trtllm-python-py3 ... 24.08 nvcr.io/nvidia/tritonserver:24.08-trtllm-python-py3 Python 3.10.12 2.4.0a0+3bcc3cddb5.nv24.7 10.3.0 0.12.0 12.6.0.022 560.35.03 21G ...'

  local kv u p c trt tllm vllm drv

  kv="$(printf '%s' "$triton_fixture" | extract_components "triton_")"
  u="$(printf '%s\n' "$kv" | kv_get triton_ubuntu_version)"; assert_eq "triton ubuntu" "$u" "22.04"
  p="$(printf '%s\n' "$kv" | kv_get triton_python_version)"; assert_eq "triton python" "$p" "3.10"
  c="$(printf '%s\n' "$kv" | kv_get triton_cuda_version)"; assert_eq "triton cuda" "$c" "12.6"
  trt="$(printf '%s\n' "$kv" | kv_get triton_tensorrt_version)"; assert_eq "triton tensorrt" "$trt" "10.3.0.26"
  tllm="$(printf '%s\n' "$kv" | kv_get triton_tensorrtllm_version)"; assert_eq "triton trtllm" "$tllm" "0.12.0"
  vllm="$(printf '%s\n' "$kv" | kv_get triton_vllm_version)"; assert_eq "triton vllm" "$vllm" "0.5.3 post 1"
  drv="$(printf '%s\n' "$kv" | kv_get triton_min_driver_branch)"; assert_eq "triton driver branch" "$drv" "560"

  kv="$(printf '%s' "$tf_fixture" | extract_components "tf_")"
  u="$(printf '%s\n' "$kv" | kv_get tf_ubuntu_version)"; assert_eq "tf ubuntu" "$u" "22.04"
  p="$(printf '%s\n' "$kv" | kv_get tf_python_version)"; assert_eq "tf python" "$p" "3.10.6"
  trt="$(printf '%s\n' "$kv" | kv_get tf_tensorrt_version)"; assert_eq "tf tensorrt" "$trt" "10.3.0.26"

  kv="$(extract_triton_matrix "24.08" "$matrix_fixture" || true)"
  vllm="$(printf '%s\n' "$kv" | kv_get triton_matrix_vllm_version)"; assert_eq "matrix vllm" "$vllm" "0.5.3post1.nv24.08.cu126"
  tllm="$(printf '%s\n' "$kv" | kv_get triton_matrix_trtllm_tensorrtllm_version)"; assert_eq "matrix trtllm" "$tllm" "0.12.0"

  echo "SELFTEST OK"
}

main() {
  if [[ "${1:-}" == "--selftest" ]]; then
    selftest
    exit 0
  fi

  if [[ $# -lt 1 ]]; then usage >&2; exit 1; fi

  local nv_release="$1"; shift
  validate_release "$nv_release"

  local mode="env"
  local strict="0"
  local key=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env) mode="env" ;;
      --json) mode="json" ;;
      --pretty) mode="pretty" ;;
      --key) shift; key="${1:-}"; [[ -z "$key" ]] && { echo "ERROR: --key needs a value" >&2; exit 1; } ;;
      --strict) strict="1" ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift || true
  done

  local rel_dash="${nv_release//./-}"

  local url_pt url_tf url_triton url_matrix
  url_pt="$(url_for_dlfw pytorch "$rel_dash")"
  url_tf="$(url_for_dlfw tensorflow "$rel_dash")"
  url_triton="$(url_for_triton_rel "$rel_dash")"
  url_matrix="$(url_triton_matrix)"

  local pt_text="" tf_text="" triton_text="" matrix_text=""
  if pt_text="$(fetch_url "$url_pt" 2>/dev/null | html_to_text)"; then :; else pt_text=""; fi
  if tf_text="$(fetch_url "$url_tf" 2>/dev/null | html_to_text)"; then :; else tf_text=""; fi
  if triton_text="$(fetch_url "$url_triton" 2>/dev/null | html_to_text)"; then :; else triton_text=""; fi
  if matrix_text="$(fetch_url "$url_matrix" 2>/dev/null | html_to_text)"; then :; else matrix_text=""; fi

  local kv_pt kv_tf kv_triton kv_matrix
  kv_pt="$(printf '%s' "$pt_text" | extract_components "pytorch_")"
  kv_tf="$(printf '%s' "$tf_text" | extract_components "tf_")"
  kv_triton="$(printf '%s' "$triton_text" | extract_components "triton_")"
  kv_matrix="$(extract_triton_matrix "$nv_release" "$matrix_text" || true)"

  # Minimal parsing of Triton "Container Versions" table row (if present) for triton_version.
  local triton_table=""
  if [[ -n "$triton_text" ]]; then
    # pattern from Triton release notes: "24.08 2.49.0 22.04 NVIDIA CUDA 12.6 TensorRT 10.3.0.26"
    local row
    row="$(printf '%s' "$triton_text" | sed -nE "s~.* ${nv_release} ([0-9][0-9.]+) ([0-9]{2}\.[0-9]{2}) .*CUDA ([0-9][0-9.]+) .*TensorRT[^-0-9]*([0-9][0-9.]+).*~\\1|\\2|\\3|\\4~p" | head -n1)" || true
    if [[ -n "$row" ]]; then
      IFS='|' read -r tr_ver tr_ub tr_cu tr_trt <<<"$row"
      triton_table="$(printf '%s\n' \
        "triton_table_triton=${tr_ver}" \
        "triton_table_ubuntu=${tr_ub}" \
        "triton_table_cuda=${tr_cu}" \
        "triton_table_tensorrt=${tr_trt}")"
    fi
  fi

  # Merge everything, then add a unified "best" stack (no prefix).
  local merged_all
  merged_all="$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
    "nv_release=${nv_release}" \
    "source_pytorch=${url_pt}" \
    "source_tensorflow=${url_tf}" \
    "source_triton=${url_triton}" \
    "source_triton_matrix=${url_matrix}" \
    "$kv_pt" "$kv_tf" "$kv_triton" "$kv_matrix" "$triton_table" \
  | sed '/^$/d' | kv_merge)"

  pick_first() {
    local k v
    for k in "$@"; do
      v="$(printf '%s\n' "$merged_all" | kv_get "$k" || true)"
      [[ -n "$v" ]] && { printf '%s' "$v"; return 0; }
    done
    printf '%s' ""
  }

  local best
  best="$(printf '%s\n' \
    "ubuntu_version=$(pick_first triton_ubuntu_version tf_ubuntu_version pytorch_ubuntu_version triton_table_ubuntu)" \
    "python_version=$(pick_first triton_python_version tf_python_version pytorch_python_version triton_matrix_vllm_python_version triton_matrix_trtllm_python_version)" \
    "cuda_version=$(pick_first triton_cuda_version tf_cuda_version pytorch_cuda_version triton_table_cuda triton_matrix_vllm_cuda_version triton_matrix_trtllm_cuda_version)" \
    "cublas_version=$(pick_first triton_cublas_version tf_cublas_version pytorch_cublas_version)" \
    "cudnn_version=$(pick_first triton_cudnn_version tf_cudnn_version pytorch_cudnn_version)" \
    "nccl_version=$(pick_first triton_nccl_version tf_nccl_version pytorch_nccl_version)" \
    "tensorrt_version=$(pick_first triton_tensorrt_version tf_tensorrt_version pytorch_tensorrt_version triton_table_tensorrt triton_matrix_trtllm_tensorrt_version)" \
    "tensorrtllm_version=$(pick_first triton_tensorrtllm_version triton_matrix_trtllm_tensorrtllm_version)" \
    "vllm_version=$(pick_first triton_vllm_version triton_matrix_vllm_version)" \
    "triton_version=$(pick_first triton_table_triton)" \
    "min_driver_branch=$(pick_first triton_min_driver_branch)" \
  )"

  merged_all="$(printf '%s\n%s\n' "$merged_all" "$best" | sed '/^$/d' | kv_merge)"

  if [[ "$strict" == "1" ]]; then
    local must=(ubuntu_version cuda_version tensorrt_version)
    local m
    for m in "${must[@]}"; do
      if [[ -z "$(printf '%s\n' "$merged_all" | kv_get "$m" || true)" ]]; then
        echo "ERROR: strict mode: missing required key '$m' (release notes may have changed)" >&2
        exit 5
      fi
    done
  fi

  if [[ -n "$key" ]]; then
    printf '%s\n' "$(printf '%s\n' "$merged_all" | kv_get "$key" || true)"
    exit 0
  fi

  case "$mode" in
    env) printf '%s\n' "$merged_all" ;;
    json) printf '%s\n' "$merged_all" | kv_to_json ;;
    pretty) printf '%s\n' "$merged_all" | kv_pretty ;;
    *) echo "ERROR: unknown mode $mode" >&2; exit 1 ;;
  esac
}

main "$@"
