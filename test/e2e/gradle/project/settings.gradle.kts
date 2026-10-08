// Plugins et leurs dépendances cherchés d'abord sur Maven Central : le portail
// Gradle ne fait que relayer Central, et ce relais renvoie parfois « introuvable »
pluginManagement {
    repositories {
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.name = "calc"
