# Template Integration Plan — EditorBot Content Pipeline

**Date:** 21 January 2026
**Status:** Planning Phase
**Branch:** Development

---

## Overview

This document outlines the complete integration of template-based video production into the EditorBot pipeline, connecting the AWS Lambda template API with the bot's state machine for guided content creation.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Infrastructure                        │
│  Lambda API: https://qcol9gunw4.execute-api...              │
│  Endpoints: /templates, /templates/{id}, /config            │
│  S3 Bucket: bot-templates-20260121100906067300000001        │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ HTTPS (fetch templates)
                          │
┌─────────────────────────────────────────────────────────────┐
│              editorbot-stack Repository                      │
│  ├── editorBot/ (submodule)                                 │
│  │   ├── bot/state/machine.py (state machine)              │
│  │   ├── bot/handlers/ (user interaction)                  │
│  │   └── bot/templates/  ← NEW MODULE                      │
│  │       ├── client.py      (API calls)                    │
│  │       ├── models.py      (Python models)                │
│  │       ├── validator.py   (validation logic)             │
│  │       └── cache.py       (optional caching)             │
│  └── dialect_mediator/ (submodule - unchanged)             │
└─────────────────────────────────────────────────────────────┘
```

---

## Complete User Journey & Data Flow

### State 1: IDLE → AUDIO_RECEIVED

**User Action:** Sends voice message to Telegram bot

**Bot Response:**
```
🎤 Audio recibido. Transcribiendo...
```

**Data:**
```python
Conversation(
    state=AUDIO_RECEIVED
)
```

**Backend:** Voice file downloaded, Whisper transcribing (local CPU)

---

### State 2: AUDIO_RECEIVED → TRANSCRIBED

**Event:** `TRANSCRIPTION_COMPLETE`

**Data:**
```python
Conversation(
    state=TRANSCRIBED,
    transcript="[Venezuelan Spanish raw transcript]"
)
```

**Backend:** Whisper completes, no user message (internal state)

---

### State 3: TRANSCRIBED → MEDIATED

**Backend:**
- Calls `dialect_mediator` submodule
- Uses Gemini API to convert Venezuelan Spanish → neutral Spanish

**Bot Response:**
```
✍️ Texto mediado (borrador):

[Cleaned, neutral Spanish text]

Responde con:
- OK
- EDITAR (pegando texto)
- CANCELAR
```

**Data:**
```python
Conversation(
    state=MEDIATED,
    transcript="[raw Venezuelan Spanish]",
    mediated_text="[neutral Spanish]"
)
```

---

### State 4: MEDIATED → SCRIPT_DRAFTED

**User Action:** Types "OK" or provides edited text

**Backend:** LLM generates structured script with:
- Beats (atomic narrative segments)
- Timing information
- Beat roles (hook, argument, conclusion, etc.)
- Structure type (linear_argument, nested_exploration, etc.)

**Bot Response:**
```
📝 Guión generado:

Beat 1 (Hook): "¿Alguna vez te preguntaste...?"
Beat 2 (Argument): "La realidad es que..."
Beat 3 (Conclusion): "Por eso debemos..."

Duración estimada: 52s
Estructura: linear_argument

Responde con:
- OK (confirmar)
- EDITAR (modificar)
- CANCELAR
```

**Data:**
```python
Conversation(
    state=SCRIPT_DRAFTED,
    transcript="[transcript]",
    mediated_text="[mediated]",
    script_draft={
        "beats": [
            {"role": "hook", "text": "...", "duration": 8},
            {"role": "argument", "text": "...", "duration": 35},
            {"role": "conclusion", "text": "...", "duration": 9}
        ],
        "total_duration": 52,
        "structure_type": "linear_argument"
    }
)
```

---

### State 5: SCRIPT_DRAFTED → FINAL_SCRIPT

**User Action:** Types "OK"

**Bot Response:**
```
✅ Guión confirmado.
```

**Data:**
```python
Conversation(
    state=FINAL_SCRIPT,
    # ...previous fields...,
    final_script={...}  # Copy of script_draft
)
```

---

### State 6: FINAL_SCRIPT → TEMPLATE_PROPOSED ⭐ NEW

**User Action:** Types "OK" or "NEXT"

**Backend:**
- 🌐 **API Call:** `GET https://.../templates`
- Receives list of template summaries

**Bot Response:**
```
✅ Guion final confirmado. Ahora elige un template:

[Telegram Inline Keyboard]
┌──────────────────────────┐
│ 🎤 Opinion Monologue     │
│ 30-60s | Reel vertical   │
├──────────────────────────┤
│ 📊 Explainer Slides      │
│ 45-90s | Slides/Reel     │
├──────────────────────────┤
│ 🎬 Narrated Thought      │
│ 60-120s | Video 16:9     │
└──────────────────────────┘
```

**Data:**
```python
Conversation(
    state=TEMPLATE_PROPOSED,
    # ...previous fields...,
    available_templates=[
        {
            "id": "opinion_monologue_reel",
            "name": "Opinion Monologue",
            "description": "Fast-paced vertical reel with strong viewpoint",
            "intent_profile": "opinion"
        },
        # ... other templates
    ]
)
```

**User sees:** Template options as clickable buttons

---

### State 7: TEMPLATE_PROPOSED → SELECT_SOUNDTRACK ⭐ VALIDATION

**User Action:** Clicks template button (callback query)

**Backend:**
1. 🌐 **API Call:** `GET https://.../templates/{id}`
2. Receives full template specification
3. 🔍 **Validates script against template:**

#### Validation Rules Checked:

**Duration:**
```python
script_duration = final_script["total_duration"]  # 52s
min_allowed = template_spec["duration"]["min_seconds"]  # 30s
max_allowed = template_spec["duration"]["max_seconds"]  # 60s

if not (min_allowed <= script_duration <= max_allowed):
    validation_error("Duration out of range")
```

**Structure Type:**
```python
script_structure = final_script["structure_type"]  # "linear_argument"
allowed_structures = template_spec["script_structure"]["allowed_structure_types"]

if script_structure not in allowed_structures:
    validation_error("Structure type not allowed")
```

**Beat Count:**
```python
beat_count = len(final_script["beats"])  # 3
min_beats = template_spec["script_structure"]["min_beats"]  # 3
max_beats = template_spec["script_structure"]["max_beats"]  # 5

if not (min_beats <= beat_count <= max_beats):
    validation_error("Beat count out of range")
```

**Required Roles:**
```python
script_roles = {beat["role"] for beat in final_script["beats"]}
required_roles = template_spec["script_structure"]["required_roles"]

for role in required_roles:
    if role not in script_roles:
        validation_error(f"Missing required role: {role}")
```

**Forbidden Roles:**
```python
forbidden_roles = template_spec["script_structure"]["forbidden_roles"]

for role in script_roles:
    if role in forbidden_roles:
        validation_error(f"Forbidden role present: {role}")
```

#### Response Cases:

**Case A: Validation PASSES (strict template)**
```
✅ Template seleccionado: Opinion Monologue

Tu guión cumple con todos los requisitos:
• Duración: 52s (límite: 30-60s) ✅
• Estructura: linear_argument ✅
• Beats: 3 (rango: 3-5) ✅
• Roles requeridos: hook ✅, argument ✅

Ahora elige una banda sonora...
```

→ Transitions to SELECT_SOUNDTRACK

**Case B: Validation FAILS (strict template)**
```
❌ Este guión NO es compatible con Opinion Monologue

Problemas detectados:
• Duración: 95s (máximo: 60s) ❌
• Beat prohibido: "call_to_action" no permitido ❌
• Falta beat requerido: "hook" ❌

Opciones:
1. EDITAR - modificar el guión
2. CAMBIAR - elegir otro template
3. CANCELAR - reiniciar

Responde: EDITAR, CAMBIAR, o CANCELAR
```

→ Stays in TEMPLATE_PROPOSED or goes back to SCRIPT_DRAFTED

**Case C: Validation WARNING (flexible template)**
```
⚠️ Template: Explainer Slides (modo flexible)

Sugerencias de mejora:
• Duración: 85s (óptimo: 75s, máximo: 90s)
  → Sugerencia: reducir 10s para mejor ritmo
• Beat count: 9 (óptimo: 6, máximo: 8)
  → Sugerencia: combinar beats similares

¿Continuar de todas formas?
- OK (proceder)
- EDITAR (ajustar guión)
```

→ Can continue to SELECT_SOUNDTRACK even with warnings

**Data:**
```python
Conversation(
    state=SELECT_SOUNDTRACK,  # Only if passes or user overrides
    # ...previous fields...,
    template_id="opinion_monologue_reel",
    template_spec={
        "id": "opinion_monologue_reel",
        "name": "Opinion Monologue",
        "duration": {
            "min_seconds": 30,
            "target_seconds": 45,
            "max_seconds": 60
        },
        "script_structure": {
            "allowed_structure_types": ["linear_argument"],
            "min_beats": 3,
            "max_beats": 5,
            "required_roles": ["hook", "argument"],
            "optional_roles": ["counterpoint", "conclusion"],
            "forbidden_roles": ["exposition", "call_to_action"]
        },
        "audio_rules": {
            "voice_policy": "required",
            "music_allowed": true
        },
        "visual_rules": {
            "visual_strategy": "mixed",
            "visuals_required": true
        },
        "enforcement": {
            "strict": true,
            "violation_strategy": "reject"
        }
    },
    validation_result={
        "passed": true,
        "errors": [],
        "warnings": [],
        "checked_at": "2026-01-21T11:30:00Z"
    }
)
```

---

### State 8: SELECT_SOUNDTRACK → ASSET_OPTIONS

**User Action:** Selects soundtrack from options

**Bot Response:**
```
🎵 Banda sonora seleccionada: Upbeat Energy

Configurando generación de imágenes...
```

**Data:**
```python
Conversation(
    state=ASSET_OPTIONS,
    # ...previous fields...,
    soundtrack_id="upbeat_energy_01"
)
```

---

### State 9: ASSET_OPTIONS → READY_FOR_RENDER

**User Action:** Confirms asset generation strategy

**Backend:**
- Template's `visual_strategy` determines approach:
  - `"mixed"` → generate scene images with prompts
  - `"slides"` → simpler text-based slides
  - `"optional"` → user can skip or minimal visuals
- May trigger GPU instance for image generation
- Or queue for batch processing

**Bot Response:**
```
🎨 Configuración completada

Resumen del proyecto:
─────────────────────────
Template:     Opinion Monologue
Formato:      Reel vertical (9:16)
Duración:     52s
Banda sonora: Upbeat Energy
Imágenes:     5 escenas (a generar)
─────────────────────────

¿Proceder con la producción?
- RENDERIZAR
- REVISAR (ver detalles)
- CANCELAR
```

**Data:**
```python
Conversation(
    state=READY_FOR_RENDER,
    # ...all previous fields...,
    asset_config={
        "image_count": 5,
        "visual_strategy": "mixed",
        "prompts_generated": true,
        "format": "REEL_VERTICAL"
    }
)
```

---

### State 10: READY_FOR_RENDER → IDLE

**User Action:** Types "RENDERIZAR"

**Backend:**
1. Uses template.allowed_formats → determines output format (9:16)
2. Generates/retrieves assets from S3
3. Assembles video with FFmpeg/MoviePy:
   - Burns subtitles (if template.visual_rules.text_overlay_required)
   - Syncs audio with visuals
   - Applies template constraints
4. Uploads to S3
5. Sends download link to user

**Bot Response:**
```
🎬 Iniciando renderizado...

[Progress bar or status updates]

⏳ Procesando audio... ✅
⏳ Generando imágenes... ✅
⏳ Ensamblando video... ✅
⏳ Agregando subtítulos... ✅

✅ ¡Video completado!

[Video file attached or download link]

Duración: 52s
Formato: Reel 9:16
Tamaño: 8.3 MB
```

**Data:**
```python
Conversation(
    state=IDLE,  # Cycle complete, ready for new project
    # All previous data cleared
)
```

---

## Implementation Plan

### Phase 2: Application Layer (editorbot-stack/editorBot)

#### Session 1: Foundation (Steps 1-3)

**Step 1: Switch to Development Branch**
```bash
cd editorbot-stack/editorBot
git checkout Development
git status
git log --oneline -5  # Verify state machine updates present
```

**Step 2: Create Template Module Structure**
```bash
mkdir -p bot/templates
touch bot/templates/__init__.py
touch bot/templates/models.py
touch bot/templates/client.py
touch bot/templates/validator.py
touch bot/templates/cache.py
```

**Step 3: Implement models.py**
```python
# bot/templates/models.py
from dataclasses import dataclass
from typing import List, Optional, Dict, Any

@dataclass
class Duration:
    min_seconds: int
    target_seconds: int
    max_seconds: int

@dataclass
class ScriptStructure:
    allowed_structure_types: List[str]
    min_beats: int
    max_beats: int
    required_roles: List[str]
    optional_roles: List[str]
    forbidden_roles: List[str]

@dataclass
class AudioRules:
    voice_policy: str  # "required" | "optional" | "forbidden"
    music_allowed: bool

@dataclass
class VisualRules:
    visual_strategy: str  # "subtitles_only" | "slides" | "mixed" | "optional"
    visuals_required: bool

@dataclass
class Enforcement:
    strict: bool
    violation_strategy: str  # "reject" | "suggest_adjustments"

@dataclass
class TemplateSpec:
    id: str
    name: str
    description: str
    intent_profile: str
    allowed_formats: List[str]
    duration: Duration
    script_structure: ScriptStructure
    audio_rules: AudioRules
    visual_rules: VisualRules
    enforcement: Enforcement

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'TemplateSpec':
        """Create TemplateSpec from JSON data"""
        return cls(
            id=data['id'],
            name=data['name'],
            description=data['description'],
            intent_profile=data['intent_profile'],
            allowed_formats=data['allowed_formats'],
            duration=Duration(**data['duration']),
            script_structure=ScriptStructure(**data['script_structure']),
            audio_rules=AudioRules(**data['audio_rules']),
            visual_rules=VisualRules(**data['visual_rules']),
            enforcement=Enforcement(**data['enforcement'])
        )
```

**Deliverables:**
- ✅ Module structure created
- ✅ Type-safe Python models
- ✅ JSON deserialization working

**Test:**
```bash
cd editorbot-stack/editorBot
python3 -c "from bot.templates.models import TemplateSpec; print('✅ Import successful')"
```

---

#### Session 2: Core Logic (Steps 4-5)

**Step 4: Implement client.py**
```python
# bot/templates/client.py
import os
import requests
from typing import List, Optional, Dict
from .models import TemplateSpec

API_BASE_URL = os.environ.get(
    'TEMPLATE_API_URL',
    'https://qcol9gunw4.execute-api.eu-central-1.amazonaws.com'
)

class TemplateClient:
    def __init__(self, base_url: str = API_BASE_URL, timeout: int = 10):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout

    def list_templates(self) -> List[Dict]:
        """Fetch template summaries"""
        try:
            response = requests.get(
                f"{self.base_url}/templates",
                timeout=self.timeout
            )
            response.raise_for_status()
            data = response.json()
            return data.get('templates', [])
        except requests.RequestException as e:
            print(f"Error fetching templates: {e}")
            return []

    def get_template(self, template_id: str) -> Optional[TemplateSpec]:
        """Fetch full template specification"""
        try:
            response = requests.get(
                f"{self.base_url}/templates/{template_id}",
                timeout=self.timeout
            )
            response.raise_for_status()
            data = response.json()

            if data.get('success'):
                return TemplateSpec.from_dict(data['template'])
            return None

        except requests.RequestException as e:
            print(f"Error fetching template {template_id}: {e}")
            return None
```

**Step 5: Implement validator.py**
```python
# bot/templates/validator.py
from typing import Dict, List, Any
from .models import TemplateSpec

class ValidationResult:
    def __init__(self):
        self.passed = True
        self.errors: List[str] = []
        self.warnings: List[str] = []

    def add_error(self, message: str):
        self.passed = False
        self.errors.append(message)

    def add_warning(self, message: str):
        self.warnings.append(message)

    def to_dict(self) -> Dict[str, Any]:
        return {
            'passed': self.passed,
            'errors': self.errors,
            'warnings': self.warnings
        }


def validate_script(script: Dict, template: TemplateSpec) -> ValidationResult:
    """Validate script against template constraints"""
    result = ValidationResult()

    # 1. Check duration
    duration = script.get('total_duration', 0)
    if duration < template.duration.min_seconds:
        result.add_error(
            f"Duración {duration}s es menor al mínimo {template.duration.min_seconds}s"
        )
    elif duration > template.duration.max_seconds:
        result.add_error(
            f"Duración {duration}s excede el máximo {template.duration.max_seconds}s"
        )
    elif duration > template.duration.target_seconds:
        result.add_warning(
            f"Duración {duration}s supera el objetivo {template.duration.target_seconds}s"
        )

    # 2. Check structure type
    structure_type = script.get('structure_type')
    if structure_type not in template.script_structure.allowed_structure_types:
        result.add_error(
            f"Tipo de estructura '{structure_type}' no permitido. "
            f"Permitidos: {', '.join(template.script_structure.allowed_structure_types)}"
        )

    # 3. Check beat count
    beats = script.get('beats', [])
    beat_count = len(beats)
    if beat_count < template.script_structure.min_beats:
        result.add_error(
            f"Número de beats {beat_count} es menor al mínimo {template.script_structure.min_beats}"
        )
    elif beat_count > template.script_structure.max_beats:
        result.add_error(
            f"Número de beats {beat_count} excede el máximo {template.script_structure.max_beats}"
        )

    # 4. Check required roles
    script_roles = {beat.get('role') for beat in beats}
    for required_role in template.script_structure.required_roles:
        if required_role not in script_roles:
            result.add_error(
                f"Falta el beat requerido: '{required_role}'"
            )

    # 5. Check forbidden roles
    for role in script_roles:
        if role in template.script_structure.forbidden_roles:
            result.add_error(
                f"Beat prohibido presente: '{role}'"
            )

    return result
```

**Deliverables:**
- ✅ API client working
- ✅ Validation logic complete
- ✅ Error messages user-friendly

**Test:**
```python
# Test validation
from bot.templates.client import TemplateClient
from bot.templates.validator import validate_script

client = TemplateClient()
template = client.get_template('opinion_monologue_reel')

mock_script = {
    'total_duration': 52,
    'structure_type': 'linear_argument',
    'beats': [
        {'role': 'hook', 'duration': 8},
        {'role': 'argument', 'duration': 35},
        {'role': 'conclusion', 'duration': 9}
    ]
}

result = validate_script(mock_script, template)
print(result.to_dict())
```

---

#### Session 3: Integration (Steps 6-10)

**Step 6: Update Conversation Model**
```python
# bot/state/models.py
@dataclass(slots=True)
class Conversation:
    state: BotState = BotState.IDLE
    transcript: Optional[str] = None
    mediated_text: Optional[str] = None
    script_draft: Optional[str] = None
    final_script: Optional[str] = None

    # Template system (NEW)
    template_id: Optional[str] = None
    template_spec: Optional[Dict] = None  # Cached template JSON
    validation_result: Optional[Dict] = None

    # Existing fields
    soundtrack_id: Optional[str] = None
```

**Step 7: Update Handlers**

Update `bot/handlers/callbacks.py` for template selection:
```python
async def handle_template_selection(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle template button clicks"""
    query = update.callback_query
    await query.answer()

    chat_id = update.effective_chat.id
    template_id = query.data.split(':')[1]  # e.g., "template:opinion_monologue_reel"

    convo = get_conversation(chat_id)

    # Fetch template
    client = TemplateClient()
    template_spec = client.get_template(template_id)

    if not template_spec:
        await query.edit_message_text("❌ Error al cargar template")
        return

    # Validate script
    from bot.templates.validator import validate_script
    result = validate_script(convo.final_script, template_spec)

    if result.passed or not template_spec.enforcement.strict:
        # Proceed
        convo = handle_event(convo, EventType.TEMPLATE_SELECTED, template_id)
        convo.template_spec = template_spec.to_dict()
        convo.validation_result = result.to_dict()
        save_conversation(chat_id, convo)

        await query.edit_message_text(
            f"✅ Template seleccionado: {template_spec.name}\n\n"
            "Ahora elige una banda sonora..."
        )
    else:
        # Validation failed (strict template)
        error_msg = "❌ Este guión NO es compatible:\n\n"
        for error in result.errors:
            error_msg += f"• {error}\n"
        error_msg += "\nOpciones: EDITAR, CAMBIAR, CANCELAR"

        await query.edit_message_text(error_msg)
```

**Step 8: Add Configuration**
```bash
# On EC2 instance
echo 'TEMPLATE_API_URL=https://qcol9gunw4.execute-api.eu-central-1.amazonaws.com' >> /home/ubuntu/editorbot/.env
```

**Step 9: Write Tests**
```python
# tests/test_template_validator.py
def test_validation_passes():
    template = TemplateSpec(...)
    script = {...}
    result = validate_script(script, template)
    assert result.passed == True
    assert len(result.errors) == 0

def test_validation_fails_duration():
    # Test exceeding max duration
    ...

def test_validation_fails_forbidden_role():
    # Test forbidden beat present
    ...
```

**Step 10: Deploy & Test**
```bash
# Push to Development
git add .
git commit -m "feat: add template client and validation"
git push origin Development

# Deploy to EC2
cd editorbot-stack
./scripts/ec2_deploy.sh  # or via GitHub Actions

# Test with Telegram bot
# Send voice → verify template selection appears
```

**Deliverables:**
- ✅ Template selection in bot UI
- ✅ Validation enforced
- ✅ User feedback clear
- ✅ Deployed and working

---

## Data Architecture

### Conversation Object Schema

```python
@dataclass
class Conversation:
    # State
    state: BotState

    # Content creation pipeline
    transcript: Optional[str]           # Whisper output
    mediated_text: Optional[str]        # Dialect-cleaned text
    script_draft: Optional[Dict]        # LLM-generated script
    final_script: Optional[Dict]        # User-confirmed script

    # Template system
    template_id: Optional[str]          # Selected template ID
    template_spec: Optional[Dict]       # Full template JSON (cached)
    validation_result: Optional[Dict]   # Validation pass/fail + errors

    # Asset selection
    soundtrack_id: Optional[str]        # Selected music
    asset_config: Optional[Dict]        # Image generation config
```

### Template Specification Schema

```json
{
  "id": "opinion_monologue_reel",
  "name": "Opinion Monologue",
  "description": "Fast-paced vertical reel with strong viewpoint",
  "intent_profile": "opinion",
  "allowed_formats": ["REEL_VERTICAL"],
  "duration": {
    "min_seconds": 30,
    "target_seconds": 45,
    "max_seconds": 60
  },
  "script_structure": {
    "allowed_structure_types": ["linear_argument"],
    "min_beats": 3,
    "max_beats": 5,
    "required_roles": ["hook", "argument"],
    "optional_roles": ["counterpoint", "conclusion"],
    "forbidden_roles": ["exposition", "reflection", "call_to_action"]
  },
  "audio_rules": {
    "voice_policy": "required",
    "music_allowed": true
  },
  "visual_rules": {
    "visual_strategy": "mixed",
    "visuals_required": true
  },
  "enforcement": {
    "strict": true,
    "violation_strategy": "reject"
  }
}
```

---

## Testing Strategy

### Unit Tests
- `test_template_client.py` — API calls (mock responses)
- `test_template_validator.py` — Validation logic
- `test_template_models.py` — Model serialization

### Integration Tests
- `test_template_flow.py` — State machine with templates
- Mock Lambda API responses
- Verify state transitions

### End-to-End Tests
- Real Telegram bot conversation
- Real Lambda API calls
- Full pipeline: voice → template → validation → render

---

## Deployment Checklist

### Infrastructure (aws-content-pipeline)
- [x] Lambda API deployed
- [x] S3 bucket created
- [x] Templates uploaded
- [x] API endpoints working
- [x] CloudWatch logs configured

### Application (editorbot-stack)
- [ ] Template module created
- [ ] Validation implemented
- [ ] Handlers updated
- [ ] Tests passing
- [ ] Environment variables configured
- [ ] Deployed to EC2
- [ ] Bot tested end-to-end

### Documentation
- [ ] User guide updated
- [ ] API documentation
- [ ] Runbook for troubleshooting

---

## Rollback Plan

If template integration causes issues:

1. **Quick rollback:**
   ```bash
   git checkout main
   ./scripts/ec2_deploy.sh
   ```

2. **Disable templates:**
   - Remove template selection from FINAL_SCRIPT state
   - Bot continues without template validation

3. **Gradual rollout:**
   - Make templates optional
   - Add feature flag: `ENABLE_TEMPLATES=false`

---

## Future Enhancements

### Phase 3 (Future)
- Template caching for performance
- Custom template creation UI
- Template analytics (most used, success rates)
- A/B testing different templates
- Template versioning

### Phase 4 (Future)
- Multi-language template support
- User-uploaded templates
- Template marketplace
- Advanced validation rules

---

## Notes & Decisions

### Why Templates After Script?
- Allows content-first workflow
- User isn't constrained during creative phase
- Template acts as packaging/format decision
- Easier to validate and provide feedback

### Why Strict vs Flexible Enforcement?
- Strict (Opinion Monologue): Platform requirements, cost control
- Flexible (Explainer Slides): Creative freedom, experimentation
- Gives assistant "personality" (can push back intelligently)

### Why Cache Template Spec in Conversation?
- Reduces API calls
- Faster validation
- Works offline (for subsequent operations)
- Conversation is self-contained

---

## Questions & Open Items

- [ ] How to handle script editing after template selected?
  - **Decision:** Allow re-validation, warn if no longer compatible

- [ ] What if Lambda API is down?
  - **Decision:** Graceful degradation, use hardcoded fallback templates

- [ ] Should templates be cached locally on EC2?
  - **Decision:** Phase 3 enhancement, not critical for MVP

---

## References

- [State Machine Updates](../editorbot-stack/editorBot/bot/state/machine.py)
- [Lambda API Code](../aws-content-pipeline/lambda/config_api.py)
- [Template JSON Files](../aws-content-pipeline/templates/)
- [API Endpoint](https://qcol9gunw4.execute-api.eu-central-1.amazonaws.com)

---

**Last Updated:** 21 January 2026
**Author:** Development Team
**Status:** Ready for Implementation
