"""
Ontology normalization utilities.

Provides helpers to ensure ontology entity/edge names are valid Python
identifiers so they can safely be used as dynamically-created class names
(via ``type(name, ...)``) when setting a Zep Cloud or local Graphiti
ontology.
"""

from __future__ import annotations

import copy
import re
from typing import Any

_DEFAULT_NAME = "Unknown"


def _to_pascal_case(name: str) -> str:
    """Convert any name to PascalCase, suitable for use as a Python class name.

    Examples::

        >>> _to_pascal_case('works_for')
        'WorksFor'
        >>> _to_pascal_case('government agency')
        'GovernmentAgency'
        >>> _to_pascal_case('Person')
        'Person'
    """
    # Split on non-alphanumeric characters
    parts = re.split(r'[^a-zA-Z0-9]+', name)
    words: list[str] = []
    for part in parts:
        # Also split on camelCase boundaries (e.g. 'camelCase' → ['camel', 'Case'])
        words.extend(re.sub(r'([a-z])([A-Z])', r'\1_\2', part).split('_'))
    result = ''.join(word.capitalize() for word in words if word)
    if not result:
        return _DEFAULT_NAME
    # Python identifiers must start with a letter or underscore.
    if not result[0].isalpha() and result[0] != '_':
        result = 'T' + result
    return result


def normalize_ontology_for_zep(
    ontology: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, str]]:
    """Return a normalised copy of *ontology* suitable for Zep / Graphiti.

    Entity type names are converted to PascalCase so they can be used
    directly as Python class names in ``type(name, ...)``.  Edge type names
    are only normalised if they contain characters that would make them
    invalid Python identifiers; valid UPPER_SNAKE_CASE names such as
    ``WORKS_FOR`` are left unchanged.

    ``source`` / ``target`` references inside edge ``source_targets`` lists
    are updated to reflect any renamed entity types.

    Parameters
    ----------
    ontology:
        Ontology dict with ``entity_types`` and ``edge_types`` lists as
        produced by :class:`~app.services.ontology_generator.OntologyGenerator`.

    Returns
    -------
    normalized_ontology:
        A deep copy of *ontology* with normalised names.
    name_mapping:
        Flat mapping of ``{original_name: normalized_name}`` for every
        entity and edge type that was processed (including unchanged ones).
        Callers can inspect entries where ``original != normalized`` to
        discover which names were actually altered.
    """
    ontology = copy.deepcopy(ontology)

    # Maps original entity names → normalized entity names; used to fix
    # source/target references in edge definitions.
    entity_rename: dict[str, str] = {}
    # Combined mapping returned to callers (entity + edge names).
    name_mapping: dict[str, str] = {}

    # ------------------------------------------------------------------
    # 1. Normalize entity type names → PascalCase
    # ------------------------------------------------------------------
    for entity_def in ontology.get("entity_types", []):
        original = entity_def.get("name", "")
        normalized = _to_pascal_case(original) if original else _DEFAULT_NAME
        entity_def["name"] = normalized
        entity_rename[original] = normalized
        name_mapping[original] = normalized

    # ------------------------------------------------------------------
    # 2. Normalize edge type names and update source/target references
    # ------------------------------------------------------------------
    for edge_def in ontology.get("edge_types", []):
        original = edge_def.get("name", "")
        # Keep names that are already valid Python identifiers unchanged;
        # normalise anything that would cause ``type(name, ...)`` to fail.
        if original and not original.isidentifier():
            normalized = _to_pascal_case(original)
        else:
            normalized = original
        edge_def["name"] = normalized
        name_mapping[original] = normalized

        # Update source/target references to use the new entity names.
        for st in edge_def.get("source_targets", []):
            if st.get("source") in entity_rename:
                st["source"] = entity_rename[st["source"]]
            if st.get("target") in entity_rename:
                st["target"] = entity_rename[st["target"]]

    return ontology, name_mapping
