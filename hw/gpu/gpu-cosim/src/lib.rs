use std::fs::File;
use std::io::BufWriter;
use std::path::Path;
use std::sync::{LazyLock, Mutex};

static STATE: LazyLock<Mutex<State>> = LazyLock::new(|| Mutex::new(State::new()));

struct State {
    vga_buffer: Vec<u8>,
    sram: Vec<u16>,
}

const VGA_WIDTH: usize = 640;
const VGA_HEIGHT: usize = 480;
const VGA_BYTES: usize = VGA_WIDTH * VGA_HEIGHT * 4;
const SRAM_CAPACITY: usize = 1 * 1024 * 1024;

impl State {
    fn new() -> Self {
        let vga_buffer = Vec::with_capacity(VGA_BYTES);
        let sram = vec![0xFFFF; SRAM_CAPACITY];
        Self { vga_buffer, sram }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn vga_cycle(r: u8, g: u8, b: u8) {
    let mut state = STATE.lock().unwrap();
    state.vga_buffer.extend_from_slice(&[r, g, b, 255]);
}

#[unsafe(no_mangle)]
pub extern "C" fn vga_save_frame() {
    let mut state = STATE.lock().unwrap();

    if state.vga_buffer.len() != VGA_BYTES {
        println!(
            "Warning, skipping VGA frame save. Buffer has {}",
            state.vga_buffer.len()
        );
        return;
    }

    let path = Path::new(r"build/j63_nvc/vga_capture.png");
    let file = File::create(path).unwrap();
    let ref mut buf_writer = BufWriter::new(file);
    let mut encoder = png::Encoder::new(buf_writer, VGA_WIDTH as u32, VGA_HEIGHT as u32);
    encoder.set_color(png::ColorType::Rgba);
    encoder.set_depth(png::BitDepth::Eight);
    let mut png_writer = encoder.write_header().unwrap();
    png_writer
        .write_image_data(state.vga_buffer.as_slice())
        .unwrap();

    state.vga_buffer.truncate(0);
}

#[unsafe(no_mangle)]
pub extern "C" fn startup() {
    println!("Initializing GPU cosim");
    drop(STATE.lock().unwrap());
}

#[unsafe(no_mangle)]
pub static vhpi_startup_routines: [Option<unsafe extern "C" fn()>; 2] = [Some(startup), None];
