import { useEffect, useRef, useState } from "react";
import { Camera } from "lucide-react";
import { getCameraFrameBlob } from "../../lib/api";

interface Props {
  className?: string;
  alt?: string;
  onFrameLoaded?: (blob: Blob) => void;
  aspectRatio?: string;
}

export default function CameraLiveFeed({
  className = "",
  alt = "Camera Live Feed",
  onFrameLoaded,
  aspectRatio = "16/9",
}: Props) {
  const [imgUrl, setImgUrl] = useState<string | null>(null);
  const [hasError, setHasError] = useState(false);
  const prevUrlRef = useRef<string | null>(null);
  const isFetchingRef = useRef(false);

  useEffect(() => {
    let isMounted = true;
    let timerId: ReturnType<typeof setTimeout> | null = null;

    const fetchNextFrame = async () => {
      if (!isMounted) return;

      if (isFetchingRef.current) {
        timerId = setTimeout(fetchNextFrame, 30);
        return;
      }

      isFetchingRef.current = true;

      try {
        const blob = await getCameraFrameBlob();
        if (!isMounted) return;

        const newUrl = URL.createObjectURL(blob);

        if (prevUrlRef.current) {
          URL.revokeObjectURL(prevUrlRef.current);
        }
        prevUrlRef.current = newUrl;

        setImgUrl(newUrl);
        setHasError(false);

        if (onFrameLoaded) {
          onFrameLoaded(blob);
        }
      } catch {
        if (isMounted) {
          setHasError(true);
        }
      } finally {
        isFetchingRef.current = false;
        if (isMounted) {
          timerId = setTimeout(fetchNextFrame, 33); // ~30 FPS
        }
      }
    };

    fetchNextFrame();

    return () => {
      isMounted = false;
      if (timerId) clearTimeout(timerId);
      if (prevUrlRef.current) {
        URL.revokeObjectURL(prevUrlRef.current);
        prevUrlRef.current = null;
      }
    };
  }, [onFrameLoaded]);

  return (
    <div
      className={`relative w-full bg-black/50 overflow-hidden flex items-center justify-center ${className}`}
      style={{ aspectRatio }}
    >
      {imgUrl && !hasError ? (
        <img
          src={imgUrl}
          alt={alt}
          className="w-full h-full object-contain"
        />
      ) : (
        <div className="flex flex-col items-center justify-center">
          <Camera className="w-10 h-10 text-cyber-muted/40 mb-2 animate-pulse" />
          <p className="text-cyber-muted/60 font-mono text-xs">
            {hasError ? "WAITING FOR CAMERA FEED..." : "LOADING STREAM..."}
          </p>
        </div>
      )}
    </div>
  );
}
