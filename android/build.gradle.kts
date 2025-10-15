import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// Root-level repositories for all projects
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optional: Move build directories outside project for cleanliness
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure evaluation order
subprojects {
    project.evaluationDependsOn(":app")
}

// Custom clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
