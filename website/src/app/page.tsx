"use client";

import { motion, useScroll, useTransform, useVelocity, useSpring, useAnimationFrame } from "framer-motion";
import { useEffect, useRef, useState, MouseEvent } from "react";
import { Command, Mic, Sparkles, TerminalSquare, ShieldCheck, Zap } from "lucide-react";

/** ==============================
 *  RAW WEBGL LIQUID PLASMA SHADER 
 *  ============================== */
const vertexShaderSource = `
  attribute vec2 position;
  void main() {
    gl_Position = vec4(position, 0.0, 1.0);
  }
`;

const fragmentShaderSource = `
  precision highp float;
  uniform vec2 u_resolution;
  uniform float u_time;
  uniform vec2 u_mouse;

  void main() {
      // Normalize and aspect correct
      vec2 uv = gl_FragCoord.xy / u_resolution.xy;
      vec2 p = uv * 2.0 - 1.0;
      p.x *= u_resolution.x / u_resolution.y;

      vec2 mouse = u_mouse * 2.0 - 1.0;
      mouse.x *= u_resolution.x / u_resolution.y;
      mouse.y = -mouse.y;

      float t = u_time * 0.4;
      
      // Add intense gravity well distortion to mouse
      vec2 p2 = p - mouse * 0.5;
      float dist = length(p2);
      
      for(float i = 1.0; i < 5.0; i++) {
          p.x += 0.2 / i * cos(i * 2.0 * p.y + t) + mouse.x * 0.1 / (dist + 0.5);
          p.y += 0.2 / i * cos(i * 1.5 * p.x + t) + mouse.y * 0.1 / (dist + 0.5);
      }
      
      float intensity = 1.0 - length(p); // Center glow
      intensity = smoothstep(-0.2, 1.2, intensity);
      
      // Liquid orange / abyssal black colors
      vec3 col = vec3(0.01, 0.005, 0.02); // Deep space abyss
      col += vec3(1.0, 0.2, 0.0) * pow(intensity, 2.5); // Magma orange
      col += vec3(1.0, 0.8, 0.2) * pow(intensity, 6.0); // Hot core yellow
      
      // Tech-grid scanner lines effect
      float grid = max(
          step(0.98, fract(uv.x * 40.0)),
          step(0.98, fract(uv.y * 40.0))
      );
      col += vec3(1.0, 0.4, 0.0) * grid * 0.05 * intensity;

      gl_FragColor = vec4(col, 1.0);
  }
`;

function ShaderBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const gl = canvas.getContext("webgl");
    if (!gl) return;

    const compileShader = (type: number, source: string) => {
      const shader = gl.createShader(type)!;
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      return shader;
    };

    const program = gl.createProgram()!;
    gl.attachShader(program, compileShader(gl.VERTEX_SHADER, vertexShaderSource));
    gl.attachShader(program, compileShader(gl.FRAGMENT_SHADER, fragmentShaderSource));
    gl.linkProgram(program);
    gl.useProgram(program);

    const positionData = new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]);
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, positionData, gl.STATIC_DRAW);

    const positionLoc = gl.getAttribLocation(program, "position");
    gl.enableVertexAttribArray(positionLoc);
    gl.vertexAttribPointer(positionLoc, 2, gl.FLOAT, false, 0, 0);

    const uRes = gl.getUniformLocation(program, "u_resolution");
    const uTime = gl.getUniformLocation(program, "u_time");
    const uMouse = gl.getUniformLocation(program, "u_mouse");

    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
      gl.viewport(0, 0, canvas.width, canvas.height);
    };
    window.addEventListener("resize", resize);
    resize();

    let mouseX = 0.5;
    let mouseY = 0.5;
    const onMouseMove = (e: globalThis.MouseEvent) => {
      mouseX = e.clientX / window.innerWidth;
      mouseY = e.clientY / window.innerHeight;
    };
    window.addEventListener("mousemove", onMouseMove);

    const startTime = Date.now();
    let animationFrameId: number;

    const render = () => {
      gl.uniform2f(uRes, canvas.width, canvas.height);
      gl.uniform1f(uTime, (Date.now() - startTime) / 1000);
      gl.uniform2f(uMouse, mouseX, mouseY);
      gl.drawArrays(gl.TRIANGLES, 0, 6);
      animationFrameId = requestAnimationFrame(render);
    };
    render();

    return () => {
      window.removeEventListener("resize", resize);
      window.removeEventListener("mousemove", onMouseMove);
      cancelAnimationFrame(animationFrameId);
    };
  }, []);

  return <canvas ref={canvasRef} className="fixed inset-0 w-full h-full -z-20 pointer-events-none" />;
}

/** ==============================
 *  MATRIX GLITCH TEXT DECODER
 *  ============================== */
function GlitchText({ text, delay = 0 }: { text: string; delay?: number }) {
  const [display, setDisplay] = useState("");
  useEffect(() => {
    const chars = "!<>-_\\\\/[]{}—=+*^?#________";
    let iteration = 0;

    const timeout = setTimeout(() => {
      const interval = setInterval(() => {
        setDisplay(text.split("").map((letter, index) => {
          if (index < iteration) return text[index];
          return chars[Math.floor(Math.random() * chars.length)];
        }).join(""));

        if (iteration >= text.length) clearInterval(interval);
        iteration += 1 / 4; // Decoder speed
      }, 30);
      return () => clearInterval(interval);
    }, delay);

    return () => clearTimeout(timeout);
  }, [text, delay]);

  return <span>{display}</span>;
}

/** ==============================
 *  3D MAGNETIC PARALLAX CARDS
 *  ============================== */
function MagneticCard({ children, className }: { children: React.ReactNode; className?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [rotate, setRotate] = useState({ x: 0, y: 0 });

  const handleMouse = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!ref.current) return;
    const { clientX, clientY } = e;
    const { height, width, left, top } = ref.current.getBoundingClientRect();
    const middleX = clientX - (left + width / 2);
    const middleY = clientY - (top + height / 2);

    // Smooth pull to mouse effect + 3D rotation tilt
    setPosition({ x: middleX * 0.1, y: middleY * 0.1 });
    setRotate({ x: -middleY * 0.1, y: middleX * 0.1 });
  };

  const reset = () => {
    setPosition({ x: 0, y: 0 });
    setRotate({ x: 0, y: 0 });
  };

  return (
    <motion.div
      ref={ref}
      onMouseMove={handleMouse}
      onMouseLeave={reset}
      animate={{ x: position.x, y: position.y, rotateX: rotate.x, rotateY: rotate.y }}
      transition={{ type: "spring", stiffness: 150, damping: 15, mass: 0.1 }}
      className={className}
      style={{ perspective: 1200, transformStyle: "preserve-3d" }}
    >
      <div style={{ transform: "translateZ(30px)", width: '100%', height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
        {children}
      </div>
    </motion.div>
  );
}

/** ==============================
 *  MAIN CRAZY IMPLEMENTATION
 *  ============================== */
export default function MaximalistLandingPage() {
  const [mounted, setMounted] = useState(false);

  // SCROLL VELOCITY DOM DISTORTION (The mind-melting effect)
  const { scrollY } = useScroll();
  const scrollVelocity = useVelocity(scrollY);
  const smoothVelocity = useSpring(scrollVelocity, { damping: 50, stiffness: 400 });
  const skewVelocity = useTransform(smoothVelocity, [-1000, 1000], [-3, 3]);
  const scaleVelocity = useTransform(smoothVelocity, [-1000, 0, 1000], [1.05, 1, 1.05]);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return null;

  return (
    <main className="relative min-h-screen font-body overflow-x-hidden text-white bg-black selection:bg-orange-500 selection:text-white">

      {/* Extreme Custom WebGL Magma Shader */}
      <ShaderBackground />

      {/* Global DOM Distortion Container */}
      <motion.div style={{ skewY: skewVelocity, scaleY: scaleVelocity }} className="relative z-10 origin-center">

        <div className="custom-cursor hidden md:block" id="cursor"></div>
        <div className="grain"></div>

        {/* Navbar */}
        <nav className="fixed top-6 left-1/2 -translate-x-1/2 w-[90%] max-w-7xl z-50 pointer-events-auto">
          <motion.div
            initial={{ y: -50, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 1, ease: "easeOut" }}
            className="glass-holographic rounded-full px-8 py-4 flex justify-between items-center"
          >
            <div className="text-xl md:text-2xl font-display font-bold tracking-widest text-white uppercase flex items-center gap-3">
              <div className="w-3 h-3 md:w-4 md:h-4 rounded-full bg-orange-500 animate-[pulse_2s_infinite]"></div>
              Orange
            </div>
            <div className="hidden md:flex gap-8 text-sm uppercase tracking-[0.2em] font-medium text-white/70">
              <a href="#architecture" className="hover:text-white transition-colors hover-target">Architecture</a>
              <a href="#stats" className="hover:text-white transition-colors hover-target">Performance</a>
            </div>
            <button className="btn-magnetic px-6 py-2 rounded-full bg-orange-500/10 border border-orange-500 text-orange-500 hover:text-white uppercase text-xs md:text-sm font-bold tracking-widest hover-target">
              Deploy
            </button>
          </motion.div>
        </nav>

        {/* Hero Section */}
        <section className="relative h-screen flex flex-col items-center justify-center pt-20 px-4">
          <div className="relative z-10 text-center w-full flex flex-col items-center max-w-7xl mx-auto">
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ duration: 1, delay: 0.2 }}
              className="inline-flex items-center gap-2 rounded-full border border-orange-500/30 bg-orange-500/10 px-4 py-1.5 text-xs font-bold tracking-widest uppercase text-orange-400 backdrop-blur mb-8"
            >
              <Sparkles className="w-3 h-3" />
              <span>Native macOS Edge Agent</span>
            </motion.div>

            <h1 className="text-[12vw] md:text-[8vw] leading-[0.85] font-display font-black uppercase text-transparent bg-clip-text bg-gradient-to-br from-white via-white to-white/30 tracking-tighter hover-target">
              <GlitchText text="SPEAK." delay={500} />
            </h1>
            <h1 className="text-[12vw] md:text-[8vw] leading-[0.85] font-display font-black uppercase text-transparent bg-clip-text bg-gradient-to-r from-orange-500 to-yellow-500 tracking-tighter hover-target -mt-2 md:-mt-6 drop-shadow-[0_0_80px_rgba(255,100,0,0.4)]">
              <GlitchText text="EXECUTE." delay={1200} />
            </h1>

            <motion.p
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 1, delay: 2 }}
              className="mt-10 text-lg md:text-2xl max-w-2xl text-white/50 font-light leading-relaxed tracking-wide"
            >
              The surgical precision of a natively compiled macOS AI agent. Voice-to-action bypasses the GUI. We build the future.
            </motion.p>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 1, delay: 2.2 }}
              className="mt-12"
            >
              <button className="hover-target group relative flex items-center justify-center gap-3 rounded-full bg-orange-500 px-8 py-4 font-bold text-black transition-all hover:bg-orange-400 btn-magnetic text-lg tracking-widest uppercase">
                <Mic className="w-5 h-5 flex-shrink-0" />
                <span>Initialize Local Beta</span>
              </button>
            </motion.div>
          </div>
        </section>

        {/* Architecture Bento Grid */}
        <section id="architecture" className="py-32 px-4 md:px-12 max-w-[1600px] mx-auto relative z-10">
          <motion.h2
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 0.15 }}
            viewport={{ once: true }}
            className="text-6xl md:text-[10vw] font-display font-black uppercase mb-16 tracking-tighter"
          >
            Architecture
          </motion.h2>

          <div className="grid grid-cols-1 md:grid-cols-3 md:grid-rows-2 gap-6 h-auto md:h-[800px]">

            {/* Large Card w/ Magnetic Pull */}
            <MagneticCard className="glass-holographic rounded-[2.5rem] p-10 md:col-span-2 relative overflow-visible group hover-target border border-white/10">
              <div className="absolute inset-0 bg-gradient-to-br from-orange-500/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none rounded-[2.5rem]"></div>
              <div>
                <div className="w-16 h-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center mb-8 backdrop-blur-md">
                  <Command className="w-8 h-8 text-orange-400 shadow-orange-500" />
                </div>
                <h3 className="text-4xl md:text-5xl font-display font-bold uppercase mb-4 text-white tracking-tight leading-none group-hover:text-orange-400 transition-colors duration-500">Native Swift<br />Runtime</h3>
              </div>
              <p className="text-xl md:text-2xl text-white/50 max-w-lg leading-relaxed font-light">Zero-latency hooks deep into window management and accessibility APIs. Unmatched execution speed.</p>
              <div className="absolute -right-10 -bottom-20 text-[20rem] opacity-[0.03] font-display font-black leading-none pointer-events-none group-hover:opacity-[0.08] transition-opacity duration-700" style={{ transform: "translateZ(-50px)" }}>OS</div>
            </MagneticCard>

            {/* Tall Card */}
            <MagneticCard className="glass-holographic rounded-[2.5rem] p-10 md:row-span-2 relative overflow-hidden group hover-target border border-white/10">
              <div className="absolute top-0 right-0 w-full h-full bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI4IiBoZWlnaHQ9IjgiPgo8cmVjdCB3aWR0aD0iOCIgaGVpZ2h0PSI4IiBmaWxsPSIjZmZmIiBmaWxsLW9wYWNpdHk9IjAuMDUiPjwvcmVjdD4KPHBhdGggZD0iTTAgMEw4IDhaTTAgOEw4IDBaIiBzdHJva2U9IiMwMDAiIHN0cm9rZS1vcGFjaXR5PSIwLjEiPjwvcGF0aD4KPC9zdmc+')] opacity-20 group-hover:opacity-40 transition-opacity duration-500 pointer-events-none rounded-[2.5rem]" style={{ transform: "translateZ(-20px)" }}></div>
              <div className="absolute top-10 left-10">
                <TerminalSquare className="w-10 h-10 text-white/30 group-hover:text-white/80 transition-colors drop-shadow-[0_0_20px_rgba(255,255,255,0.2)]" />
              </div>
              <div className="mt-auto">
                <h3 className="text-4xl font-display font-bold uppercase mb-4 tracking-tight leading-none group-hover:text-transparent group-hover:bg-clip-text group-hover:bg-gradient-to-r group-hover:from-white group-hover:to-white/50 transition-all">Python<br />Sidecar</h3>
                <p className="text-lg text-white/50 font-light leading-relaxed">Abstract AST generation, multimodal reasoning endpoints, deterministic fluid planning.</p>
              </div>
            </MagneticCard>

            {/* Small Card 1 */}
            <MagneticCard className="glass-holographic rounded-[2.5rem] p-8 md:p-10 relative overflow-hidden group hover-target border border-white/10">
              <ShieldCheck className="w-8 h-8 text-orange-500 mb-6 drop-shadow-[0_0_20px_rgba(255,100,0,0.6)]" />
              <div>
                <h3 className="text-2xl md:text-3xl font-display font-bold uppercase mb-2 text-white">Contract First</h3>
                <p className="text-base text-white/60 font-light blur-[0.5px] group-hover:blur-none transition-all duration-300">Strictly typed schemas cross boundaries flawlessly. Fail-closed safety mechanisms.</p>
              </div>
            </MagneticCard>

            {/* Small Card 2 */}
            <MagneticCard className="glass-holographic rounded-[2.5rem] p-8 md:p-10 relative overflow-hidden group hover-target border border-white/10">
              <div className="absolute inset-0 bg-orange-500/5 group-hover:bg-orange-500/20 transition-colors duration-500 pointer-events-none rounded-[2.5rem]"></div>
              <Zap className="w-8 h-8 text-white relative z-10 mb-6 drop-shadow-[0_0_15px_rgba(255,255,255,0.8)]" />
              <div className="relative z-10">
                <h3 className="text-2xl md:text-3xl font-display font-bold uppercase mb-2">Cross-App Flow</h3>
                <p className="text-base text-white/60 font-light text-shadow-[0_2px_10px_rgba(0,0,0,0.5)]">Mail &#8594; Slack &#8594; Safari &#8594; Finder. Invisible connective tissue across macOS.</p>
              </div>
            </MagneticCard>

          </div>
        </section>

        {/* Performance Stats Section */}
        <section id="stats" className="py-32 relative z-10 bg-[#020202]/80 backdrop-blur-3xl border-y border-white/5 mt-20">
          <div className="container mx-auto px-4 flex flex-col md:flex-row justify-around items-center gap-16 md:gap-12 text-center">
            <motion.div
              initial={{ scale: 0.8, opacity: 0 }}
              whileInView={{ scale: 1, opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 1 }}
              className="hover-target"
            >
              <div className="text-7xl lg:text-[10rem] font-display font-black text-transparent bg-clip-text bg-gradient-to-b from-white to-white/10 leading-none drop-shadow-2xl">0</div>
              <div className="uppercase tracking-[0.3em] text-orange-500 font-bold mt-6 text-sm">Latency (ms)</div>
            </motion.div>
            <motion.div
              initial={{ scale: 0.8, opacity: 0 }}
              whileInView={{ scale: 1, opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 1, delay: 0.2 }}
              className="hover-target"
            >
              <div className="text-7xl lg:text-[10rem] font-display font-black text-transparent bg-clip-text bg-gradient-to-b from-white to-white/10 leading-none drop-shadow-2xl">100</div>
              <div className="uppercase tracking-[0.3em] text-orange-500 font-bold mt-6 text-sm">Task Completion %</div>
            </motion.div>
          </div>
        </section>

        {/* Hyper Marquee Footer */}
        <footer className="relative z-10 py-32 overflow-hidden border-t border-white/10 flex flex-col justify-center min-h-[60vh] bg-black pointer-events-auto">
          <div className="absolute inset-0 z-0 bg-gradient-to-b from-transparent to-orange-500/10 pointer-events-none"></div>

          <div className="w-full flex overflow-hidden whitespace-nowrap mb-20 hover-target py-10 rotate-[-2deg] bg-orange-500/10 backdrop-blur-md border-y border-orange-500/30 relative z-10">
            <div className="animate-marquee inline-block">
              <span className="text-[8vw] md:text-[6vw] font-display font-black uppercase text-stroke px-8">Let's build the future //</span>
              <span className="text-[8vw] md:text-[6vw] font-display font-black uppercase text-stroke px-8">Let's build the future //</span>
            </div>
            <div className="animate-marquee inline-block" aria-hidden="true">
              <span className="text-[8vw] md:text-[6vw] font-display font-black uppercase text-stroke px-8">Let's build the future //</span>
              <span className="text-[8vw] md:text-[6vw] font-display font-black uppercase text-stroke px-8">Let's build the future //</span>
            </div>
          </div>

          <div className="max-w-[1600px] w-full mx-auto px-12 flex flex-col md:flex-row justify-between items-end text-white/30 text-xs md:text-sm font-bold uppercase tracking-[0.2em] relative z-10">
            <div className="mb-4 md:mb-0 hover:text-white transition-colors cursor-default hover-target">&copy; 2026 ORANGE</div>
            <div className="flex gap-8">
              <a href="#" className="hover:text-orange-500 transition-colors hover-target">Privacy</a>
              <a href="#" className="hover:text-orange-500 transition-colors hover-target">Terms</a>
              <a href="#" className="hover:text-orange-500 transition-colors hover-target">Contact us</a>
            </div>
          </div>
        </footer>

      </motion.div>
    </main>
  );
}
