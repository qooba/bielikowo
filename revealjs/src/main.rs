use actix_files as fs;
use actix_web::middleware::Logger;
use actix_web::{App, HttpServer};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let host = "0.0.0.0";
    let port = 55555;
    println!("Embedde-rs server running on http://{host}:{port}");
    let mut server = HttpServer::new(move || {
        App::new()
            .wrap(Logger::default())
            .service(fs::Files::new("/", "./").show_files_listing())
        //.service(fs::Files::new("/", "./public").show_files_listing())
    });

    server = server.workers(1);

    server.bind((host, port))?.run().await
}
