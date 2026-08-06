import { Canvas } from "@react-three/fiber";
import { useRef } from "react";
import * as THREE from "three";

function Grid() {
  const ref = useRef<THREE.GridHelper>(null);
  return (
    <gridHelper
      ref={ref}
      args={[40, 40, "#00f0ff", "#001133"]}
      position={[0, -2, 0]}
    />
  );
}

function Particles() {
  const points = useRef<THREE.Points>(null);
  const count = 200;
  const positions = new Float32Array(count * 3);
  
  for (let i = 0; i < count; i++) {
    positions[i * 3] = (Math.random() - 0.5) * 20;
    positions[i * 3 + 1] = (Math.random() - 0.5) * 10;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 20;
  }

  return (
    <points ref={points}>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
            args={[positions, 3]}
        />
      </bufferGeometry>
      <pointsMaterial size={0.03} color="#00f0ff" transparent opacity={0.6} />
    </points>
  );
}

export default function CyberGrid() {
  return (
    <div className="fixed inset-0 -z-10 pointer-events-none">
      <Canvas camera={{ position: [0, 2, 8], fov: 60 }}>
        <ambientLight intensity={0.5} />
        <Grid />
        <Particles />
      </Canvas>
    </div>
  );
}