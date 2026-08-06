import os

os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

from app.services import LiveRecognitionEngine


def main():
    print("🎥 Starting Smooth Live Recognition...")
    print("Press 'q' to exit")

    engine = LiveRecognitionEngine(
        process_every_n_frames=5,  # Har 5th frame pe recognition
        camera_id=0,
        display_size=(1280, 720),
    )

    engine.run()


if __name__ == "__main__":
    main()
