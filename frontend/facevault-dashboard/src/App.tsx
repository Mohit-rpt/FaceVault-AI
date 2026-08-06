import { lazy, Suspense } from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Layout from "./components/layout/Layout";

// Lazy load pages for fast initial bundle load
const Dashboard = lazy(() => import("./pages/Dashboard"));
const Persons = lazy(() => import("./pages/Persons"));
const PersonProfile = lazy(() => import("./pages/PersonProfile"));
const RegisterFace = lazy(() => import("./pages/RegisterFace"));
const LiveRecognition = lazy(() => import("./pages/LiveRecognition"));
const RecognitionLogs = lazy(() => import("./pages/RecognitionLogs"));
const Timeline = lazy(() => import("./pages/Timeline"));
const UnknownFaces = lazy(() => import("./pages/UnknownFaces"));
const Analytics = lazy(() => import("./pages/Analytics"));
const Settings = lazy(() => import("./pages/Settings"));
const CameraSettings = lazy(() => import("./pages/CameraSettings"));

function PageLoader() {
  return (
    <div className="flex items-center justify-center min-h-[60vh]">
      <div className="w-8 h-8 border-2 border-cyber-cyan border-t-transparent rounded-full animate-spin" />
    </div>
  );
}

function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={<PageLoader />}>
        <Routes>
          <Route element={<Layout />}>
            <Route path="/" element={<Dashboard />} />
            <Route path="/persons" element={<Persons />} />
            <Route path="/persons/:id" element={<PersonProfile />} />
            <Route path="/register-face" element={<RegisterFace />} />
            <Route path="/live" element={<LiveRecognition />} />
            <Route path="/logs" element={<RecognitionLogs />} />
            <Route path="/timeline" element={<Timeline />} />
            <Route path="/unknown" element={<UnknownFaces />} />
            <Route path="/analytics" element={<Analytics />} />
            <Route path="/camera" element={<CameraSettings />} />
            <Route path="/settings" element={<Settings />} />
          </Route>
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}

export default App;