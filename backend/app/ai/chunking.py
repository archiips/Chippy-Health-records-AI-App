"""
Document-type-aware chunking strategy.

Per architecture spec:
  lab_result        → SentenceSplitter(256 tokens, 20 overlap)
  radiology         → SemanticSplitterNodeParser (adaptive)
  discharge_summary → SentenceWindowNodeParser(window_size=3)
  clinical_note     → SentenceWindowNodeParser(window_size=3)
  insurance         → SentenceSplitter(512 tokens, 50 overlap)
  other/prescription→ SentenceSplitter(384 tokens, 32 overlap)
"""

from llama_index.core import Document
from llama_index.core.node_parser import (
    SentenceSplitter,
    SentenceWindowNodeParser,
)
from llama_index.core.schema import TextNode


def chunk_document(
    text: str,
    doc_type: str,
) -> list[TextNode]:
    """
    Split text into LlamaIndex TextNodes using the strategy appropriate
    for the given document type.
    """
    document = Document(text=text)

    if doc_type == "lab_result":
        parser = SentenceSplitter(chunk_size=256, chunk_overlap=20)
        nodes = parser.get_nodes_from_documents([document])

    elif doc_type == "radiology":
        # SentenceWindowNodeParser preserves FINDINGS/IMPRESSION context.
        # SemanticSplitterNodeParser would be ideal but requires a separate
        # embed model init — deferred to post-MVP.
        parser = SentenceWindowNodeParser.from_defaults(window_size=3)
        nodes = parser.get_nodes_from_documents([document])

    elif doc_type in ("discharge_summary", "clinical_note"):
        parser = SentenceWindowNodeParser.from_defaults(window_size=3)
        nodes = parser.get_nodes_from_documents([document])

    elif doc_type == "insurance":
        parser = SentenceSplitter(chunk_size=512, chunk_overlap=50)
        nodes = parser.get_nodes_from_documents([document])

    else:  # prescription, other
        parser = SentenceSplitter(chunk_size=384, chunk_overlap=32)
        nodes = parser.get_nodes_from_documents([document])

    return nodes
