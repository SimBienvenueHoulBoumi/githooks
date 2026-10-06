plugins {
    java
    id("com.diffplug.spotless") version "8.10.3"
}

repositories { mavenCentral() }

dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.12.2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test { useJUnitPlatform() }

spotless { java { googleJavaFormat() } }
