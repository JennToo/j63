#[unsafe(no_mangle)]
pub extern "C" fn vga_cycle() {}

#[unsafe(no_mangle)]
pub extern "C" fn startup() {
    println!("Initializing GPU cosim");
}

#[unsafe(no_mangle)]
pub static vhpi_startup_routines: [Option<unsafe extern "C" fn()>; 2] = [Some(startup), None];
