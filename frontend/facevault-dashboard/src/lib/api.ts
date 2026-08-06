import axios, { type AxiosError, type AxiosResponse } from "axios";
import type {
  Person,
  PersonCreate,
  PersonUpdate,
  RecognitionLog,
  TimelineEvent,
  Setting,
  FaceRegistrationResponse,
  PaginatedResponse,
  CameraStatus,
  CameraType,
  CameraTestResult,
} from "../types";

// ==================== Axios Instance ====================

const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000/api/v1";

export type ApiEnvelope<T> = {
  success?: boolean;
  message?: string;
  data?: T;
  errors?: unknown;
};

export const api = axios.create({
  baseURL: API_URL,
  timeout: 30000,
  headers: {
    "Content-Type": "application/json",
  },
});

// ==================== Helpers ====================

export function getApiErrorMessage(error: unknown, fallback = "Request failed"): string {
  if (axios.isAxiosError(error)) {
    const axiosError = error as AxiosError<ApiEnvelope<unknown>>;
    const responseMessage = axiosError.response?.data?.message;
    if (responseMessage) return responseMessage;

    const detail = (axiosError.response?.data as { detail?: string } | undefined)?.detail;
    if (detail) return detail;
  }

  if (error instanceof Error && error.message) {
    return error.message;
  }

  return fallback;
}

/**
 * Unwrap a response that may or may not be wrapped in { success, data, message } envelope.
 * If the response has a `data` property with the envelope shape, extract the inner data.
 * Otherwise, return the response data as-is.
 */
export function unwrapApiResponse<T>(response: AxiosResponse<ApiEnvelope<T> | T>): T {
  const payload = response.data as ApiEnvelope<T> | T;

  if (payload && typeof payload === "object" && "success" in payload && "data" in payload) {
    return ((payload as ApiEnvelope<T>).data ?? null) as T;
  }

  return payload as T;
}

// ==================== Persons API ====================

export async function getPersons(
  page = 1,
  limit = 20,
  search?: string
): Promise<PaginatedResponse<Person>> {
  const response = await api.get<ApiEnvelope<PaginatedResponse<Person>>>("/persons", {
    params: {
      skip: (page - 1) * limit,
      limit,
      ...(search ? { search } : {}),
    },
  });
  return unwrapApiResponse(response);
}

export async function getPerson(id: number): Promise<Person> {
  const response = await api.get<ApiEnvelope<Person>>(`/persons/${id}`);
  return unwrapApiResponse(response);
}

export async function createPerson(data: PersonCreate): Promise<Person> {
  const response = await api.post<ApiEnvelope<Person> | Person>("/persons", data);
  return unwrapApiResponse(response);
}

export async function updatePerson(id: number, data: PersonUpdate): Promise<Person> {
  const response = await api.put<ApiEnvelope<Person> | Person>(`/persons/${id}`, data);
  return unwrapApiResponse(response);
}

export async function deletePerson(id: number): Promise<void> {
  await api.delete(`/persons/${id}`);
}

// ==================== Face Registration API ====================

export async function registerFace(
  personId: number,
  files: File[]
): Promise<FaceRegistrationResponse> {
  const formData = new FormData();
  files.forEach((f) => formData.append("files", f));

  const response = await api.post<ApiEnvelope<FaceRegistrationResponse> | FaceRegistrationResponse>(
    `/persons/${personId}/register-face`,
    formData,
    {
      timeout: 120000, // 2 min for large uploads
    }
  );
  return unwrapApiResponse(response);
}

// ==================== Recognition API ====================

export async function getRecognitionLogs(params?: {
  skip?: number;
  limit?: number;
  date?: string;
  person_id?: number;
}): Promise<PaginatedResponse<RecognitionLog>> {
  const response = await api.get<ApiEnvelope<PaginatedResponse<RecognitionLog>>>(
    "/recognition/logs",
    { params }
  );
  return unwrapApiResponse(response);
}

export async function recognizeFace(
  imageFile: Blob,
  cameraSource?: string
): Promise<unknown> {
  const formData = new FormData();
  formData.append("image", imageFile, "capture.jpg");
  if (cameraSource) {
    formData.append("camera_source", cameraSource);
  }

  const response = await api.post("/recognition", formData, {
    timeout: 30000,
  });
  return unwrapApiResponse(response);
}

// ==================== Timeline API ====================

export async function getPersonTimeline(
  personId: number,
  skip = 0,
  limit = 100
): Promise<TimelineEvent[]> {
  const response = await api.get<ApiEnvelope<TimelineEvent[]> | TimelineEvent[]>(
    `/persons/${personId}/timeline`,
    { params: { skip, limit } }
  );
  return unwrapApiResponse(response);
}

// ==================== Settings API ====================

export async function getSettings(): Promise<Setting[]> {
  const response = await api.get<ApiEnvelope<Setting[]> | Setting[]>("/settings");
  return unwrapApiResponse(response);
}

export async function updateSetting(key: string, value: string): Promise<Setting> {
  const response = await api.put<ApiEnvelope<Setting> | Setting>(`/settings/${key}`, {
    setting_key: key,
    setting_value: value,
  });
  return unwrapApiResponse(response);
}

// ==================== Camera API ====================

export async function connectCamera(
  url: string,
  cameraType: CameraType
): Promise<CameraStatus> {
  const response = await api.post<ApiEnvelope<CameraStatus> | CameraStatus>(
    "/camera/connect",
    { url, camera_type: cameraType }
  );
  return unwrapApiResponse(response);
}

export async function disconnectCamera(): Promise<CameraStatus> {
  const response = await api.post<ApiEnvelope<CameraStatus> | CameraStatus>(
    "/camera/disconnect"
  );
  return unwrapApiResponse(response);
}

export async function getCameraStatus(): Promise<CameraStatus> {
  const response = await api.get<ApiEnvelope<CameraStatus> | CameraStatus>(
    "/camera/status"
  );
  return unwrapApiResponse(response);
}

export async function testCameraConnection(
  url: string
): Promise<CameraTestResult> {
  const response = await api.post<ApiEnvelope<CameraTestResult> | CameraTestResult>(
    "/camera/test",
    { url }
  );
  return unwrapApiResponse(response);
}

export function getCameraStreamUrl(): string {
  return `${API_URL}/camera/stream`;
}

export async function getCameraFrameBlob(): Promise<Blob> {
  const response = await api.get("/camera/frame", { responseType: "blob" });
  return response.data;
}

export default api;