# Tasks: One-Click AI Sandbox

**Input**: Design documents from `/specs/001-ai-sandbox/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are OPTIONAL - not explicitly requested in feature specification. Focus on manual deployment testing and integration validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Infrastructure/Deployment**: `stackscripts/`, `docker/`, `docs/`, `scripts/` at repository root
- Paths based on plan.md structure for Marketplace App deployment

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create project directory structure per implementation plan (stackscripts/, docker/, docs/, scripts/)
- [x] T002 [P] Create StackScripts directory structure in stackscripts/
- [x] T003 [P] Create Docker configuration directory in docker/
- [x] T004 [P] Create documentation directory structure in docs/
- [x] T005 [P] Create scripts directory structure in scripts/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 Create StackScript framework with error handling in stackscripts/ai-sandbox.sh
- [x] T007 [P] Create docker-compose.yml template with service definitions in docker/docker-compose.yml.template
- [x] T008 [P] Create error handling functions for /etc/motd updates in stackscripts/ai-sandbox.sh
- [x] T009 [P] Create logging infrastructure in stackscripts/ai-sandbox.sh (log directory: /var/log/ai-sandbox/)
- [x] T010 Create directory creation logic for /opt/models and /opt/open-webui in stackscripts/ai-sandbox.sh
- [x] T011 [P] Create security warning message template for /etc/motd in stackscripts/ai-sandbox.sh

**Checkpoint**: Foundation ready - independent deployment can now begin

---

## Phase 3: Independent Deployment & Testing (Priority: Pre-Marketplace) 🎯 FIRST

**Goal**: Create repeatable way to build and deploy directly to Linode without Marketplace UI. This enables development, testing, and demonstration before engaging with Marketplace team.

**Independent Test**: Use scripts to create Linode GPU instance, deploy StackScript directly, and verify services work. This provides working system to demonstrate to Marketplace team.

### Implementation for Independent Deployment

- [x] T041 [P] Create script to create Linode GPU instance via API/CLI in scripts/create-instance.sh (for independent testing)
- [x] T042 [P] Create script to deploy StackScript directly to Linode instance via API/CLI in scripts/deploy-direct.sh (independent of Marketplace)
- [x] T043 [P] Create script to run StackScript on existing Linode instance in scripts/run-stackscript.sh (for testing on existing instances)
- [x] T044 Create end-to-end deployment workflow script in scripts/deploy-full.sh (combines create-instance + deploy-direct for one-command deployment)
- [x] T045 [P] Create script to validate deployment success in scripts/validate-services.sh (API and UI accessibility checks)
- [x] T046 [P] Create script to clean up test instances in scripts/cleanup-instance.sh (for development iteration)

**Checkpoint**: At this point, you have a repeatable way to build and deploy directly to Linode. You can now demonstrate a working system to the Marketplace team.

---

## Phase 4: User Story 1 - Deploy and Access AI Chat Interface (Priority: P1) 🎯 MVP

**Goal**: Enable users to deploy the Marketplace App and immediately access a working chat interface in their browser

**Independent Test**: Deploy the Marketplace App, wait 3-5 minutes, then access the web chat interface at http://INSTANCE_IP:3000 and successfully have a conversation with the AI model. Chat history should persist across browser sessions.

### Implementation for User Story 1

- [x] T012 [US1] Add Open WebUI service definition to docker/docker-compose.yml.template (image: ghcr.io/open-webui/open-webui:main, port: 3000)
- [x] T013 [US1] Configure Open WebUI volume mount for chat history persistence (/opt/open-webui) in docker/docker-compose.yml.template
- [x] T014 [US1] Configure Open WebUI to connect to vLLM API service in docker/docker-compose.yml.template (environment variable: OPENAI_API_BASE_URL)
- [x] T015 [US1] Add Open WebUI service startup to StackScript docker-compose generation in stackscripts/ai-sandbox.sh
- [x] T016 [US1] Add chat interface access instructions to /etc/motd in stackscripts/ai-sandbox.sh (URL: http://INSTANCE_IP:3000)
- [x] T017 [US1] Add service health check for Open WebUI in stackscripts/ai-sandbox.sh (verify port 3000 is accessible)
- [x] T018 [US1] Add chat history persistence validation in stackscripts/ai-sandbox.sh (verify /opt/open-webui directory exists and is writable)

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently - users can deploy and access the chat interface

---

## Phase 4: User Story 2 - Access OpenAI-Compatible API Endpoint (Priority: P2)

**Goal**: Provide a stable, OpenAI-compatible API endpoint that existing applications can use by changing BASE_URL

**Independent Test**: Deploy the Marketplace App, wait for services to be ready, then make a standard OpenAI API v1 format request to http://INSTANCE_IP:8000/v1/chat/completions and receive a valid response. Multiple concurrent requests should be queued and processed sequentially.

### Implementation for User Story 2

- [x] T019 [US2] Add vLLM service definition to docker/docker-compose.yml.template (image: ghcr.io/vllm-project/vllm-openai:latest, port: 8000)
- [x] T020 [US2] Configure vLLM model environment variable (MODEL_ID=mistralai/Mistral-7B-Instruct-v0.3) in docker/docker-compose.yml.template
- [x] T021 [US2] Configure vLLM GPU passthrough (gpus: all) in docker/docker-compose.yml.template
- [x] T022 [US2] Configure vLLM model cache volume mount (/opt/models) in docker/docker-compose.yml.template
- [x] T023 [US2] Configure vLLM for sequential request processing (no parallel inference) in docker/docker-compose.yml.template
- [x] T024 [US2] Add vLLM service startup to StackScript docker-compose generation in stackscripts/ai-sandbox.sh
- [x] T025 [US2] Add API endpoint access instructions to /etc/motd in stackscripts/ai-sandbox.sh (URL: http://INSTANCE_IP:8000/v1)
- [x] T026 [US2] Add service health check for vLLM API in stackscripts/ai-sandbox.sh (verify port 8000 is accessible and responds to OpenAI API v1 format)
- [x] T027 [US2] Add OpenAI API v1 compatibility validation in stackscripts/ai-sandbox.sh (test /v1/chat/completions endpoint)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - users can access both chat interface and API endpoint

---

## Phase 6: Marketplace Integration

**Goal**: Integrate working system with Linode Marketplace App framework for one-click deployment via Marketplace UI

**Prerequisites**: Phases 1-5 must be complete with working independent deployment

**Independent Test**: Deploy via Marketplace UI, verify same functionality as independent deployment. Marketplace deployment should produce identical results to direct deployment.

### Implementation for Marketplace Integration

- [ ] T047 Create Marketplace App manifest/configuration file (marketplace-app.json or similar)
- [ ] T048 Configure Marketplace UDF (User-Configurable Fields) for model selection (future use, currently fixed)
- [ ] T049 Integrate StackScript with Marketplace deployment workflow
- [ ] T050 Create Marketplace App documentation and screenshots for Marketplace listing
- [ ] T051 Test Marketplace deployment end-to-end (create instance via Marketplace UI)
- [ ] T052 Validate Marketplace deployment matches independent deployment behavior
- [ ] T053 Create Marketplace-specific deployment instructions in docs/marketplace-deployment.md

**Checkpoint**: At this point, the system works both via independent deployment AND via Marketplace UI. Ready for Marketplace team review and approval.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T028 [P] Create deployment documentation in docs/deployment.md (deployment instructions, configuration options)
- [ ] T029 [P] Create troubleshooting guide in docs/troubleshooting.md (common errors, solutions, log locations)
- [ ] T030 [P] Create security configuration guide in docs/security.md (firewall setup, access control recommendations)
- [ ] T031 [P] Create automated deployment testing script in scripts/test-deployment.sh (clean instance deployment validation)
- [ ] T033 Add comprehensive error handling for model download failures in stackscripts/ai-sandbox.sh (network errors, invalid model ID)
- [ ] T034 Add error handling for insufficient GPU resources in stackscripts/ai-sandbox.sh (instance type validation, error message in /etc/motd)
- [ ] T035 Add error handling for service startup failures in stackscripts/ai-sandbox.sh (driver issues, port conflicts, error messages in /etc/motd)
- [ ] T036 Add error handling for disk space issues in stackscripts/ai-sandbox.sh (model download space check, error message in /etc/motd)
- [ ] T037 Add automatic service restart configuration in docker/docker-compose.yml.template (restart: unless-stopped for both services)
- [ ] T038 Add service startup on boot configuration in stackscripts/ai-sandbox.sh (docker-compose up -d with restart policies)
- [ ] T039 Add deployment status tracking in stackscripts/ai-sandbox.sh (write deployment status to /var/log/ai-sandbox/deployment.log)
- [ ] T040 Validate quickstart.md instructions by following them from scratch

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all subsequent phases
- **Independent Deployment (Phase 3)**: Depends on Foundational completion - CRITICAL for development workflow
- **User Stories (Phase 4+)**: All depend on Foundational phase completion
  - Can proceed in parallel with Independent Deployment (Phase 3) if needed
  - Or sequentially in priority order (P1 → P2)
- **Marketplace Integration (Phase 6)**: Depends on User Stories completion - Requires working system first
- **Polish (Final Phase)**: Depends on Marketplace Integration completion

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Depends on vLLM service which is independent of US1, but both services use same model instance

### Within Each User Story

- Docker Compose configuration before StackScript integration
- Service definitions before health checks
- Core service setup before access instructions
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T002, T003, T004, T005)
- Foundational tasks marked [P] can run in parallel (T007, T008, T009, T011)
- Once Foundational phase completes, user stories can start in parallel (if team capacity allows)
- Polish documentation tasks marked [P] can run in parallel (T028, T029, T030, T031, T032)
- Error handling tasks can be implemented in parallel (T033, T034, T035, T036)

---

## Parallel Example: User Story 1

```bash
# These tasks can run in parallel (different files, no dependencies):
Task: "Add Open WebUI service definition to docker/docker-compose.yml.template"
Task: "Add chat interface access instructions to /etc/motd in stackscripts/ai-sandbox.sh"
Task: "Add service health check for Open WebUI in stackscripts/ai-sandbox.sh"
```

---

## Implementation Strategy

### 🎯 RECOMMENDED: Independent Deployment First (For Marketplace Demo)

**Priority**: Get working system via independent deployment BEFORE Marketplace integration

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all phases)
3. **Complete Phase 3: Independent Deployment** (CRITICAL - enables development and demo)
   - Create scripts for direct Linode deployment
   - Test end-to-end deployment workflow
   - **STOP and VALIDATE**: You now have a working system to demonstrate
4. Complete Phase 4: User Story 1 (Chat Interface)
5. Complete Phase 5: User Story 2 (API Endpoint)
6. **STOP and VALIDATE**: Full working system via independent deployment
   - Deploy using scripts/scripts
   - Verify chat interface accessible at http://INSTANCE_IP:3000
   - Verify API endpoint at http://INSTANCE_IP:8000/v1
   - **You now have a working demo for Marketplace team**
7. Complete Phase 6: Marketplace Integration (after Marketplace team engagement)
8. Complete Phase 7: Polish & Cross-Cutting

### Alternative: MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: Independent Deployment (enables testing)
4. Complete Phase 4: User Story 1
5. **STOP and VALIDATE**: Test User Story 1 independently
   - Deploy using independent deployment scripts
   - Verify chat interface accessible at http://INSTANCE_IP:3000
   - Verify chat history persists
6. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. **Complete Independent Deployment (Phase 3)** → Can now deploy and test without Marketplace
3. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
   - Deploy using independent deployment scripts
   - Verify chat interface works
4. Add User Story 2 → Test independently → Deploy/Demo
   - Verify API endpoint responds to OpenAI API v1 requests
   - Verify sequential request queuing works
5. **Add Marketplace Integration (Phase 6)** → After Marketplace team engagement
   - Integrate working system with Marketplace framework
   - Verify Marketplace deployment matches independent deployment
6. Each phase adds value without breaking previous phases

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (Open WebUI service)
   - Developer B: User Story 2 (vLLM API service)
3. Stories complete and integrate independently (both use same model instance)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- This is an infrastructure/deployment project - tasks focus on StackScripts, Docker Compose, and deployment automation rather than application code
- **PRIORITY**: Independent deployment (Phase 3) comes FIRST to enable development and Marketplace team demonstration
- Marketplace integration (Phase 6) comes AFTER we have a working system
- Manual testing on clean Linode GPU instances is required for validation
- All error messages must be written to /etc/motd for user visibility
- All detailed logs must be written to /var/log/ai-sandbox/ for troubleshooting

