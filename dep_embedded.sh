#!/bin/bash

# GitHub License, Version, Dependency, and Embedded License Checker
# This script checks the license, latest release version, a specific version, dependency licenses, and embedded licenses of a GitHub repository.
# It supports checking dependencies for JavaScript (Node.js), Python, Scala, and Java.

# Function to display usage
usage() {
    echo "Usage: $0 <owner/repo> [specific_version]"
    exit 1
}

# Check if repository is provided
if [ -z "$1" ]; then
    usage
fi

# Extract owner and repo from input
REPO=$1
SPECIFIC_VERSION=$2

# GitHub API URLs
LICENSE_API_URL="https://api.github.com/repos/$REPO/license"
VERSION_API_URL="https://api.github.com/repos/$REPO/releases/latest"
REPO_API_URL="https://api.github.com/repos/$REPO"
SPECIFIC_VERSION_API_URL="https://api.github.com/repos/$REPO/tags"

# Fetch license information
LICENSE_RESPONSE=$(curl -s $LICENSE_API_URL)

# Check if repository is not found
if echo "$LICENSE_RESPONSE" | grep -q "Not Found"; then
    echo "Repository not found: $REPO"
    exit 1
fi

# Extract license name
LICENSE=$(echo "$LICENSE_RESPONSE" | jq -r '.license.spdx_id')

# Check if license is found
if [ -z "$LICENSE" ] || [ "$LICENSE" == "null" ]; then
    echo "No license found for repository: $REPO"
else
    echo "The license for repository $REPO is: $LICENSE"
fi

# Fetch latest release version information
VERSION_RESPONSE=$(curl -s $VERSION_API_URL)

# Check if repository is not found or no releases are available
if echo "$VERSION_RESPONSE" | grep -q "Not Found"; then
    echo "No releases found for repository: $REPO"
else
    # Extract latest release version tag
    LATEST_VERSION=$(echo "$VERSION_RESPONSE" | jq -r '.tag_name')

    # Check if latest release version is found
    if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" == "null" ]; then
        echo "No release version found for repository: $REPO"
    else
        echo "The latest release version for repository $REPO is: $LATEST_VERSION"
    fi
fi

# Fetch repository information
REPO_RESPONSE=$(curl -s $REPO_API_URL)

# Check if repository is not found
if echo "$REPO_RESPONSE" | grep -q "Not Found"; then
    echo "Repository not found: $REPO"
    exit 1
fi

# Extract repository version (default branch commit SHA)
REPO_VERSION=$(echo "$REPO_RESPONSE" | jq -r '.default_branch')

# Check if repository version is found
if [ -z "$REPO_VERSION" ] || [ "$REPO_VERSION" == "null" ]; then
    echo "No repository version found for repository: $REPO"
else
    echo "The repository version for repository $REPO is: $REPO_VERSION"
fi

# Fetch specific version information if provided
if [ -n "$SPECIFIC_VERSION" ]; then
    SPECIFIC_VERSION_RESPONSE=$(curl -s $SPECIFIC_VERSION_API_URL)

    # Check if specific version is found
    if echo "$SPECIFIC_VERSION_RESPONSE" | grep -q "\"name\": \"$SPECIFIC_VERSION\""; then
        echo "The specific version $SPECIFIC_VERSION exists in repository $REPO"
    else
        echo "The specific version $SPECIFIC_VERSION does not exist in repository $REPO"
    fi
fi

# Function to check dependency licenses for Node.js (JavaScript)
check_node_dependencies() {
    PACKAGE_JSON_URL="https://raw.githubusercontent.com/$REPO/master/package.json"
    PACKAGE_JSON_RESPONSE=$(curl -s $PACKAGE_JSON_URL)
    
    if echo "$PACKAGE_JSON_RESPONSE" | grep -q "Not Found"; then
        echo "No package.json file found for repository: $REPO"
    else
        DEPENDENCIES=$(echo "$PACKAGE_JSON_RESPONSE" | jq -r '.dependencies // empty | keys[]?' | sort -u)
        DEV_DEPENDENCIES=$(echo "$PACKAGE_JSON_RESPONSE" | jq -r '.devDependencies // empty | keys[]?' | sort -u)
        
        if [ -z "$DEPENDENCIES" ] && [ -z "$DEV_DEPENDENCIES" ]; then
            echo "No dependencies found in package.json for repository: $REPO"
        else
            echo "The dependencies for repository $REPO are:"
            echo "$DEPENDENCIES"
            echo "$DEV_DEPENDENCIES"
            echo "Checking licenses for each dependency..."
            while IFS= read -r dep_name; do
                dep_license_url="https://registry.npmjs.org/$dep_name/latest"
                dep_license_response=$(curl -s $dep_license_url)
                dep_license=$(echo "$dep_license_response" | jq -r '.license')
                if [ -z "$dep_license" ] || [ "$dep_license" == "null" ]; then
                    echo "No license found for dependency: $dep_name"
                else
                    echo "The license for dependency $dep_name is: $dep_license"
                fi
            done <<< "$DEPENDENCIES $DEV_DEPENDENCIES"
        fi
    fi
}

# Function to check dependency licenses for Python
check_python_dependencies() {
    REQUIREMENTS_TXT_URL="https://raw.githubusercontent.com/$REPO/master/requirements.txt"
    REQUIREMENTS_TXT_RESPONSE=$(curl -s $REQUIREMENTS_TXT_URL)
    
    if echo "$REQUIREMENTS_TXT_RESPONSE" | grep -q "Not Found"; then
        echo "No requirements.txt file found for repository: $REPO"
    else
        if [ -z "$REQUIREMENTS_TXT_RESPONSE" ]; then
            echo "No dependencies found in requirements.txt for repository: $REPO"
        else
            echo "The dependencies for repository $REPO are:"
            echo "$REQUIREMENTS_TXT_RESPONSE"
            echo "Checking licenses for each dependency..."
            while IFS= read -r dep; do
                dep_name=$(echo "$dep" | cut -d '=' -f1)
                dep_license_url="https://pypi.org/pypi/$dep_name/json"
                dep_license_response=$(curl -s $dep_license_url)
                dep_license=$(echo "$dep_license_response" | jq -r '.info.license')
                if [ -z "$dep_license" ] || [ "$dep_license" == "null" ]; then
                    echo "No license found for dependency: $dep_name"
                else
                    echo "The license for dependency $dep_name is: $dep_license"
                fi
            done <<< "$REQUIREMENTS_TXT_RESPONSE"
        fi
    fi
}

# Function to check dependency licenses for Scala
check_scala_dependencies() {
    BUILD_SBT_URL="https://raw.githubusercontent.com/$REPO/master/build.sbt"
    BUILD_SBT_RESPONSE=$(curl -s $BUILD_SBT_URL)
    
    if echo "$BUILD_SBT_RESPONSE" | grep -q "Not Found"; then
        echo "No build.sbt file found for repository: $REPO"
    else
        if echo "$BUILD_SBT_RESPONSE" | grep -q 'libraryDependencies'; then
            echo "The dependencies for repository $REPO are:"
            echo "$BUILD_SBT_RESPONSE" | grep 'libraryDependencies' | sed 's/.*libraryDependencies += "\(.*\)".*/\1/'
            echo "Note: Checking Scala dependencies license requires manual intervention."
        else
            echo "No dependencies found in build.sbt for repository: $REPO"
        fi
    fi
}

# Function to check dependency licenses for Java
check_java_dependencies() {
    POM_XML_URL="https://raw.githubusercontent.com/$REPO/master/pom.xml"
    POM_XML_RESPONSE=$(curl -s $POM_XML_URL)
    
    if echo "$POM_XML_RESPONSE" | grep -q "Not Found"; then
        echo "No pom.xml file found for repository: $REPO"
    else
        if echo "$POM_XML_RESPONSE" | grep -q '<dependency>'; then
            echo "The dependencies for repository $REPO are:"
            echo "$POM_XML_RESPONSE" | grep '<dependency>' -A 7 | grep -E '<groupId>|<artifactId>|<version>'
            echo "Note: Checking Java dependencies license requires manual intervention."
        else
            echo "No dependencies found in pom.xml for repository: $REPO"
        fi
    fi
}

# Function to check for embedded licenses in the repository
check_embedded_licenses() {
    LICENSE_FILES=$(curl -s https://api.github.com/repos/$REPO/git/trees/$REPO_VERSION?recursive=1 | jq -r '.tree[] | select(.path | test("LICENSE|COPYING|NOTICE|LICENSE.txt|NOTICE.txt")) | .path')
    
    if [ -z "$LICENSE_FILES" ]; then
        echo "No embedded license files found in repository: $REPO"
    else
        echo "Embedded license files found in repository $REPO:"
        echo "$LICENSE_FILES"
        for file in $LICENSE_FILES; do
            echo "Contents of $file:"
            curl -s https://raw.githubusercontent.com/$REPO/$REPO_VERSION/$file
        done
    fi
}

# Check for JavaScript dependencies
check_node_dependencies

# Check for Python dependencies
check_python_dependencies

# Check for Scala dependencies
check_scala_dependencies

# Check for Java dependencies
check_java_dependencies

# Check for embedded licenses
check_embedded_licenses
