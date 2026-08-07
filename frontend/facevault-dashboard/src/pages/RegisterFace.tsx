import { useState, useRef } from "react";
import type { FormEvent } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Upload, ScanFace, CheckCircle2, X, AlertCircle, Loader2 } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import { registerFace, getApiErrorMessage } from "../lib/api";
import type { FaceRegistrationResponse } from "../types";

export default function RegisterFace() {
  const [files, setFiles] = useState<File[]>([]);
  const [personId, setPersonId] = useState("");
  const [dragActive, setDragActive] = useState(false);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<{ success: boolean; message?: string; data?: FaceRegistrationResponse } | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") setDragActive(true);
    else setDragActive(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    if (e.dataTransfer.files) {
      const newFiles = Array.from(e.dataTransfer.files).filter((f) =>
        f.type.startsWith("image/")
      );
      setFiles((prev) => [...prev, ...newFiles].slice(0, 10));
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      const newFiles = Array.from(e.target.files);
      setFiles((prev) => [...prev, ...newFiles].slice(0, 10));
    }
  };

  const removeFile = (idx: number) => {
    setFiles((prev) => prev.filter((_, i) => i !== idx));
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!personId || files.length < 3) return;

    setLoading(true);
    setResult(null);

    try {
      const data = await registerFace(Number(personId), files);
      setResult({
        success: true,
        message: `Registration complete: ${data.registered_images} registered, ${data.failed_images} failed`,
        data,
      });
      setFiles([]);
    } catch (err: unknown) {
      setResult({
        success: false,
        message: getApiErrorMessage(err, "Registration failed"),
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <form onSubmit={handleSubmit} className="space-y-6">
        <GlassCard>
          <h2 className="text-xl font-semibold mb-2 flex items-center gap-2">
            <ScanFace className="w-6 h-6 text-cyber-cyan" />
            BIOMETRIC REGISTRATION
          </h2>
          <p className="text-sm text-cyber-muted mb-6">
            Upload 3-10 high quality images for facial embedding training
          </p>

          <div className="mb-6">
            <label className="text-xs font-mono text-cyber-muted tracking-wider mb-2 block">
              TARGET PERSON ID
            </label>
            <input
              type="number"
              value={personId}
              onChange={(e) => setPersonId(e.target.value)}
              placeholder="Enter person ID..."
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyber-cyan/50"
              required
            />
          </div>

          <div
            onDragEnter={handleDrag}
            onDragLeave={handleDrag}
            onDragOver={handleDrag}
            onDrop={handleDrop}
            onClick={() => inputRef.current?.click()}
            className={`border-2 border-dashed rounded-xl p-12 text-center cursor-pointer transition-all duration-200 ${
              dragActive
                ? "border-cyber-cyan bg-cyber-cyan/5"
                : "border-white/10 bg-white/5 hover:border-white/20"
            }`}
          >
            <input
              ref={inputRef}
              type="file"
              multiple
              accept="image/*"
              onChange={handleChange}
              className="hidden"
            />
            <Upload className="w-12 h-12 text-cyber-muted mx-auto mb-4" />
            <p className="text-white font-medium mb-1">Drop images here</p>
            <p className="text-xs text-cyber-muted">or click to browse (3-10 images)</p>
          </div>

          {files.length > 0 && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              className="mt-4 space-y-2"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-mono text-cyber-muted">
                  {files.length} FILE{files.length !== 1 ? "S" : ""} SELECTED
                </span>
                {files.length < 3 && (
                  <span className="text-xs text-red-400 flex items-center gap-1">
                    <AlertCircle className="w-3 h-3" />
                    Minimum 3 required
                  </span>
                )}
              </div>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                <AnimatePresence>
                  {files.map((file, idx) => (
                    <motion.div
                      key={idx}
                      initial={{ opacity: 0, scale: 0.8 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 0.8 }}
                      className="relative aspect-square rounded-lg bg-black/40 border border-white/10 overflow-hidden group"
                    >
                      <img
                        src={URL.createObjectURL(file)}
                        alt=""
                        className="w-full h-full object-cover"
                      />
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          removeFile(idx);
                        }}
                        className="absolute top-1 right-1 p-1 bg-black/60 rounded-full text-white opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        <X className="w-3 h-3" />
                      </button>
                      <div className="absolute bottom-0 left-0 right-0 bg-black/60 px-2 py-1">
                        <p className="text-[10px] text-white truncate">{file.name}</p>
                      </div>
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
            </motion.div>
          )}
        </GlassCard>

        {result && (
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}>
            <GlassCard
              className={
                result.success === false
                  ? "border-red-500/30"
                  : "border-emerald-500/30"
              }
            >
              <div className="flex items-center gap-3 mb-4">
                {result.success === false ? (
                  <AlertCircle className="w-5 h-5 text-red-400" />
                ) : (
                  <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                )}
                <h3 className={result.success === false ? "text-red-400" : "text-emerald-400"}>
                  {result.message || "Registration Complete"}
                </h3>
              </div>
              {result.data && (
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                  <div className="p-3 rounded-lg bg-white/5 text-center">
                    <p className="text-lg font-bold text-white">{result.data.registered_images ?? 0}</p>
                    <p className="text-[10px] text-cyber-muted font-mono">REGISTERED</p>
                  </div>
                  <div className="p-3 rounded-lg bg-white/5 text-center">
                    <p className="text-lg font-bold text-white">{result.data.failed_images ?? 0}</p>
                    <p className="text-[10px] text-cyber-muted font-mono">FAILED</p>
                  </div>
                  <div className="p-3 rounded-lg bg-white/5 text-center">
                    <p className="text-lg font-bold text-cyber-cyan">{result.data.embeddings_created ?? 0}</p>
                    <p className="text-[10px] text-cyber-muted font-mono">EMBEDDINGS</p>
                  </div>
                  <div className="p-3 rounded-lg bg-white/5 text-center">
                    <p className="text-lg font-bold text-emerald-400">
                      {typeof result.data.average_quality === "number"
                        ? result.data.average_quality.toFixed(1)
                        : (result.data.average_quality ?? "0.0")}
                    </p>
                    <p className="text-[10px] text-cyber-muted font-mono">AVG QUALITY</p>
                  </div>
                </div>
              )}
            </GlassCard>
          </motion.div>
        )}

        <motion.button
          whileHover={{ scale: 1.01 }}
          whileTap={{ scale: 0.99 }}
          type="submit"
          disabled={loading || files.length < 3 || !personId}
          className="w-full py-3 bg-cyber-cyan text-black font-bold rounded-lg hover:bg-cyber-cyan/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          {loading ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              PROCESSING...
            </>
          ) : (
            <>
              <ScanFace className="w-4 h-4" />
              BEGIN BIOMETRIC TRAINING
            </>
          )}
        </motion.button>
      </form>
    </div>
  );
}