import java.io.File

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

fun patchPdfiumWindowsLink(cmake: File) {
    if (!cmake.exists()) {
        return
    }
    val text = cmake.readText()
    if (text.contains("PDFIUM_WINDOWS_JUNCTION")) {
        return
    }
    val original =
        "file(REMOVE \${PDFIUM_LATEST_DIR})\n" +
            "file(CREATE_LINK \${PDFIUM_LIBS_DIR} \${PDFIUM_LATEST_DIR} SYMBOLIC)"
    if (!text.contains(original)) {
        return
    }
    cmake.writeText(
        text.replace(
            original,
            """
            # PDFIUM_WINDOWS_JUNCTION
            if (CMAKE_HOST_WIN32)
                file(REMOVE_RECURSE ${'$'}{PDFIUM_LATEST_DIR})
                execute_process(
                    COMMAND cmd /c mklink /J "${'$'}{PDFIUM_LATEST_DIR}" "${'$'}{PDFIUM_LIBS_DIR}"
                    RESULT_VARIABLE PDFIUM_JUNCTION_STATUS
                    OUTPUT_QUIET
                    ERROR_QUIET
                )
                if (PDFIUM_JUNCTION_STATUS AND NOT PDFIUM_JUNCTION_STATUS EQUAL 0)
                    file(MAKE_DIRECTORY ${'$'}{PDFIUM_LATEST_DIR})
                    file(COPY ${'$'}{PDFIUM_LIBS_DIR}/ DESTINATION ${'$'}{PDFIUM_LATEST_DIR})
                endif()
            else()
                file(REMOVE ${'$'}{PDFIUM_LATEST_DIR})
                file(CREATE_LINK ${'$'}{PDFIUM_LIBS_DIR} ${'$'}{PDFIUM_LATEST_DIR} SYMBOLIC)
            endif()
            """.trimIndent(),
        ),
    )
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    if (name == "pdfium_flutter") {
        patchPdfiumWindowsLink(file("${project.projectDir}/CMakeLists.txt"))
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
