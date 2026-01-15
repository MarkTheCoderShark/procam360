# Mobile Requirements Document (MRD)

## Product Name (Working)
FieldVision (placeholder)

## Document Purpose
This MRD defines the **goals, users, functional requirements, non-functional requirements, and success metrics** for an iOS application designed to capture, organize, and manage job-site photography and project progress. This document is intended to **direct an AI coding agent (Claude Code)** to fully architect and implement the application.

---

## 1. Product Vision

### Vision Statement
Create the most **intuitive, photo-first job site documentation app** for contractors and field teams, enabling effortless capture, organization, and sharing of project progress through time-stamped, location-aware photography—enhanced by AI automation.

### Core Value Proposition
> "Every photo tells the full story of the job—where, when, and why—without extra effort from the field."

---

## 2. Target Users

### Primary Users
- Field technicians / crews
- Contractors (roofing, restoration, construction, HVAC)

### Secondary Users
- Office managers
- Project managers
- Clients (read-only / shared access)

---

## 3. Core Use Cases

1. Capture photos at a job site that are automatically:
   - Time-stamped
   - Date-stamped
   - GPS/location-stamped
2. Organize photos by:
   - Project
   - Location (room, elevation, zone)
   - Timeline (before/during/after)
3. Review progress visually via:
   - Folder structure
   - Chronological timeline
   - Map-based photo view
4. Share photos and reports with crews, managers, and clients

---

## 4. Core Features (MVP – MUST BUILD)

### 4.1 Project & Job Management

**Requirements**
- Users can create Projects (Jobs)
- Each Project contains:
  - Project name
  - Address (required for map features)
  - Client name (optional)
  - Status (Walkthrough, In Progress, Completed)

**Acceptance Criteria**
- Project creation takes <30 seconds
- Project is usable offline

---

### 4.2 Photo & Video Capture (PRIMARY FEATURE)

**Requirements**
- Native iOS camera integration
- Capture photos and videos from within the app
- Automatic metadata capture:
  - Date
  - Time
  - GPS coordinates
  - User ID
  - Project ID

**Offline Mode**
- Photos must save locally when offline
- Auto-sync when connection is restored

**Acceptance Criteria**
- Zero manual data entry required
- Metadata is immutable after capture

---

### 4.3 Photo Organization System

#### A. Folder-Based Organization

Users can organize photos into folders such as:
- By location (Kitchen, Roof – North Side, Unit A)
- By phase (Before, During, After)
- Custom folders

Folders exist **within a Project**.

#### B. Timeline View (CRITICAL)

- All photos displayed chronologically
- Filters:
  - Date range
  - Folder
  - User
- Visual progress tracking via scrollable timeline

#### C. Map View (CRITICAL)

- Map view showing photo pins
- Each pin represents:
  - Single photo or photo cluster
- Tapping a pin opens associated media

**Acceptance Criteria**
- Timeline loads <2 seconds for 1,000 photos
- Map clustering enabled for performance

---

### 4.4 Metadata & Context

Each photo must store:
- Project ID
- Folder ID (optional)
- Timestamp
- GPS coordinates
- Uploader
- Notes (manual or AI-generated)

---

## 5. AI-Assisted Features (Phase 1 – Light AI)

### 5.1 Voice-to-Notes
- User can speak a note after taking a photo
- AI transcribes and attaches text to the photo

### 5.2 Auto-Tagging (Optional MVP)
- AI suggests tags based on:
  - Spoken notes
  - Image content

---

## 6. Client Sharing & Portal Access (MVP – PRIORITY)

### 6.1 Share Links (Minimum Requirement)

**Goal:** Allow a user to generate a **secure, client-facing link** that provides access to a project’s photos/collection without requiring the client to install the app.

**Requirements**
- From a Project, user can generate a **Share Link** that opens a web-based viewer.
- Share Links can be scoped to:
  - Entire Project
  - Specific Folder(s)
  - Specific date range (optional)
- Share Link settings (configurable by Admin role):
  - Expiration (Never / 7 days / 30 days / custom date)
  - Access control (Anyone with link / Password protected)
  - Permissions:
    - View only (default)
    - Allow downloads (toggle)
    - Allow comments (toggle; optional MVP)
- Share Link must display:
  - Project name
  - Photo grid
  - Timeline view
  - Map view (if location available and allowed)
  - Photo detail view with timestamp + optional notes

**Acceptance Criteria**
- Link loads on mobile web and desktop web
- Client can browse photos within <2 seconds for up to 500 photos (initial pagination acceptable)
- Access is revoked instantly when link is disabled

### 6.2 Client Role (Optional for MVP; Recommended)

**Requirements**
- Invite Client as a "Viewer" role (read-only) via email
- Viewer can:
  - View shared projects
  - Filter by folder/date
  - View timeline and map
- Viewer cannot:
  - Upload media
  - Edit metadata
  - Access internal notes marked “Internal”

---

## 7. Collaboration (MVP)

- Invite users to a Project
- Roles:
  - Admin
  - Crew
  - Viewer (client)
- Commenting on photos (crew/admin)
- Push notifications for comments (crew/admin)

---

## 7. Non-Functional Requirements

### Performance
- App launch <2 seconds
- Photo upload in background
- Timeline smooth at 60fps

### Security
- Encrypted media storage
- Role-based access control
- Secure share links

### Scalability
- Unlimited photos per project
- Cloud-based storage

---

## 8. Platform & Tech Constraints

### iOS
- Swift + SwiftUI
- Minimum iOS version: iOS 16
- Native camera APIs

### Backend (Guidance)
- REST or GraphQL API
- Cloud object storage for media
- Relational DB for metadata

---

## 9. Out of Scope (MVP)

- Invoicing
- Payments
- Advanced damage detection
- Desktop app (mobile-first)

---

## 10. Success Metrics

- Time to capture & organize photo: <5 seconds
- Daily active usage on job sites
- Reduction in manual documentation work

---

## 11. Open Design Principles (For AI Agent)

- Photo-first UX
- Zero-friction capture
- Offline-first reliability
- Metadata is automatic, never manual
- Timeline and map are first-class views

---

## 12. Deliverables Expected from AI Agent

- iOS app source code
- Backend API
- Database schema
- Cloud storage setup
- Deployment instructions
- App Store–ready build

---

## 13. Expansion Opportunities (Post-MVP)

- AI-generated project reports (PDF)
- Client-facing portals
- Integrations (QuickBooks, Jobber)
- Portfolio & sales tools

---

## End of MRD

