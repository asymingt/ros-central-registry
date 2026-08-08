import sys
import os
from pathlib import Path
import subprocess

def main():
    # Find the shiboken6 binary in runfiles
    import shiboken6_generator
    pkg_dir = Path(shiboken6_generator.__file__).parent
    binary_path = pkg_dir / "shiboken6"
    
    if not binary_path.exists():
        print(f"Error: binary not found at {binary_path}", file=sys.stderr)
        sys.exit(1)
        
    # Locate the PySide6 typesystems directory so that shiboken can resolve
    # typesystem_core.xml, typesystem_gui.xml and typesystem_widgets.xml.
    # PySide6 ships these files in its package's "typesystems/" subdirectory.
    typesystem_paths = []
    try:
        import PySide6
        pyside6_dir = Path(PySide6.__file__).parent
        typesystems_dir = pyside6_dir / "typesystems"
        if typesystems_dir.is_dir():
            typesystem_paths.append(str(typesystems_dir))
    except ImportError:
        pass

    # Build the command, injecting --typesystem-paths before the user args.
    command = [os.fspath(binary_path)]
    if typesystem_paths:
        command += [f"--typesystem-paths={':'.join(typesystem_paths)}"]
    command += sys.argv[1:]
    
    # Call the binary
    sys.exit(subprocess.call(command))

if __name__ == "__main__":
    main()
