// ==================== Person ====================
export interface Person {
  person_id: number;
  name: string;
  nickname?: string;
  relationship?: string;
  created_at?: string;
  updated_at?: string;
  details?: PersonDetail;
  images?: FaceImage[];
  timelines?: TimelineEvent[];
  embeddings?: FaceEmbedding[];
  custom_fields?: CustomField[];
}

export interface PersonDetail {
  details_id?: number;
  person_id?: number;
  phone?: string;
  email?: string;
  company?: string;
  college?: string;
  designation?: string;
  address?: string;
  city?: string;
  state?: string;
  country?: string;
  birthday?: string;
  remarks?: string;
  created_at?: string;
  updated_at?: string;
}

export interface PersonCreate {
  name: string;
  nickname?: string;
  relationship?: string;
  details?: Omit<PersonDetail, "details_id" | "person_id" | "created_at" | "updated_at">;
}

export interface PersonUpdate {
  name?: string;
  nickname?: string;
  relationship?: string;
  details?: Omit<PersonDetail, "details_id" | "person_id" | "created_at" | "updated_at">;
}

// ==================== Face Image ====================
export interface FaceImage {
  image_id: number;
  person_id: number;
  image_path: string;
  capture_source?: string;
  quality_score?: number;
  image_hash?: string;
  created_at?: string;
}

// ==================== Face Embedding ====================
export interface FaceEmbedding {
  embedding_id: number;
  person_id: number;
  faiss_vector_id: number;
  model_name: string;
  model_version?: string;
  embedding_dimension: number;
  quality_score?: number;
  capture_angle?: string;
  capture_source?: string;
  is_active?: boolean;
  created_at?: string;
}

// ==================== Recognition Log ====================
export interface RecognitionLog {
  log_id: number;
  person_id: number;
  confidence_score: number;
  camera_source?: string;
  recognition_time_ms?: number;
  recognized_at?: string;
  person?: {
    person_id: number;
    name: string;
    nickname?: string;
    relationship?: string;
  };
}

// ==================== Timeline ====================
export interface TimelineEvent {
  timeline_id: number;
  person_id: number;
  interaction_date: string;
  title: string;
  description?: string;
  location?: string;
  tags?: string;
  created_at?: string;
}

// ==================== Custom Field ====================
export interface CustomField {
  field_id: number;
  person_id: number;
  field_name: string;
  field_value?: string;
  created_at?: string;
}

// ==================== Setting ====================
export interface Setting {
  setting_id: number;
  setting_key: string;
  setting_value?: string;
  updated_at?: string;
}

// ==================== Face Registration ====================
export interface FaceRegistrationDetail {
  filename: string;
  status: string;
  reason?: string | null;
  quality_score?: number | null;
  embedding_id?: number;
  image_id?: number;
}

export interface FaceRegistrationResponse {
  person_id: number;
  registered_images: number;
  failed_images: number;
  embeddings_created: number;
  average_quality: number;
  details: FaceRegistrationDetail[];
}

// ==================== Paginated Response ====================
export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  pages: number;
}

// ==================== API Envelope ====================
export interface ApiResponse<T> {
  success: boolean;
  message: string;
  data: T;
  errors?: unknown;
}

// ==================== Camera ====================
export type CameraType = "mobile" | "cctv" | "local";

export interface CameraStatus {
  connected: boolean;
  state: string;
  url: string | null;
  camera_type: CameraType | null;
  fps: number;
  resolution: { width: number; height: number } | null;
  error: string | null;
}

export interface CameraConnectRequest {
  url: string;
  camera_type: CameraType;
}

export interface CameraTestResult {
  ok: boolean;
  resolution: { width: number; height: number } | null;
  error: string | null;
}