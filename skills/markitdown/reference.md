# markitdown — Advanced reference

Heavy/optional usage. Read this only when the CLI quick reference in `SKILL.md` is not enough.

## Python API
```python
from markitdown import MarkItDown

md = MarkItDown(enable_plugins=False)   # plugins off by default
result = md.convert("report.pdf")       # path, URL, or file-like
print(result.text_content)              # the Markdown string
```
- `result.text_content` holds the Markdown; `result.title` may hold a detected title.
- Prefer the narrowest path: pass a real file path/extension so the right converter is chosen.

## LLM image descriptions (captions)
Generate descriptions for images instead of just OCR/EXIF. Pass any OpenAI-compatible client:
```python
from markitdown import MarkItDown
from openai import OpenAI

client = OpenAI()                                  # or an Azure/OpenAI-compatible client
md = MarkItDown(llm_client=client, llm_model="gpt-4o")
print(md.convert("diagram.jpg").text_content)
```
Use when an image carries meaning (charts, screenshots) and plain OCR is insufficient.

## Azure Document Intelligence (scanned PDFs, complex layouts)
Best for scanned documents or PDFs with intricate tables where the offline converter struggles.

CLI:
```bash
markitdown scanned.pdf -d -e "https://<resource>.cognitiveservices.azure.com/"
```
Python:
```python
md = MarkItDown(docintel_endpoint="https://<resource>.cognitiveservices.azure.com/")
print(md.convert("scanned.pdf").text_content)
```
Requires the `[az-doc-intel]` extra and valid Azure credentials.

## Azure Content Understanding (video)
Built-in converters do **not** handle video. Use Content Understanding:
```bash
markitdown clip.mp4 --use-cu --cu-endpoint "https://<resource>.../"
```
Requires the `[az-content-understanding]` extra.

## Plugins (3rd-party converters)
Plugins are off by default. Discover and enable explicitly:
```bash
markitdown --list-plugins          # show installed plugins
markitdown -p custom.fmt           # convert using plugins
```
Python: `MarkItDown(enable_plugins=True)`. Install a plugin like any pip package (e.g. `pip install markitdown-sample-plugin`).

## Optional extras (install groups)
Install only what you need, or `[all]`:
```
all  ·  pdf  ·  docx  ·  pptx  ·  xlsx  ·  xls  ·  outlook
audio-transcription  ·  youtube-transcription
az-doc-intel  ·  az-content-understanding
```
```bash
uv tool install 'markitdown[pdf,docx,pptx,xlsx]'   # or pipx / pip
```

## Other flags worth knowing
- `-x/--extension` and `-m/--mime-type` — hints when reading from stdin (no filename to detect from).
- `-c/--charset` — force a text encoding (e.g. `UTF-8`).
- `--keep-data-uris` — keep base64-embedded images instead of truncating them.

## Security note
markitdown performs I/O with the privileges of the current process and will follow URLs/embedded resources. Sanitize inputs from untrusted sources before converting.
