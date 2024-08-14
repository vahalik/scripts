param(
    [string]$mainBranch = "master",
    [string[]]$branches = @("tomasvahalik/fleet/createaction", "tomasvahalik/fleet/resource+overview", "tomasvahalik/fleet/tierCreation", "tomasvahalik/fleet/createDB"), # Array of branches to merge
    [string]$workingDirectory = ".",
    [switch]$help = $false
)

# Show help how to use the script
function Show-Help {
    Write-Host "Usage: sync-branches.ps1 [-mainBranch <mainBranch>] [-branches <branch1>,<branch2>,...] [-workingDirectory <workingDirectory>]"
    Write-Host "Parameters:"
    Write-Host "  -mainBranch: The main branch to merge other branches into. Default is 'master'."
    Write-Host "  -branches: The list of branches to merge. Specify multiple branches separated by commas."
    Write-Host "  -workingDirectory: The working directory where the Git repository is located. Default is the current directory."
    Write-Host "Example: sync-branches.ps1 -mainBranch main -branches feature1,feature2,feature3 -workingDirectory C:\Projects\MyProject"
}


# save current directory to return to it later
$currentDirectory = Get-Location

function Exit-Script {
    param(
        [int]$exitCode = 0
    )

    Set-Location $currentDirectory
    exit $exitCode
}

# Check if help flag is present
if ($args -contains "-help" -or $args -contains "-h") {
    Show-Help
    Exit-Script
}

# Change to the working directory
Set-Location $workingDirectory

# Function to merge branches and handle conflicts
function Merge-Branch {
    param(
        [string]$targetBranch,
        [string]$sourceBranch
    )

    git checkout $targetBranch
    if ($?) {
        git pull origin $targetBranch
        git merge $sourceBranch
        
        if (-not $?) {
            Write-Host "Merge conflicts detected in $targetBranch. Please resolve them and commit the changes."
            Read-Host -Prompt "Press Enter after resolving conflicts"

            # Ensure conflicts are resolved and changes committed
            git status | Select-String "Unmerged paths" -quiet
            if ($LASTEXITCODE -ne 0) {
                Write-Error -Message "Conflicts are not resolved. Exiting script."
                Exit-Script -exitCode 1
            }

            Write-Host "Conflicts resolved. Continuing script."
        }
    }
    else {
        Write-Error -Message "Failed to switch to branch $targetBranch"
        Exit-Script -exitCode 1
    }
}

# Check if Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error -Message "Git is not installed. Please install Git and try again."
    Exit-Script -exitCode 1
}

# Check if current directory is a Git repository
if (-not (Test-Path .git)) {
    Show-Help
    # new line
    Write-Host ""
    # Error message
    Write-Error -Message "Current directory is not a Git repository. Please navigate to a Git repository and try again."
    Exit-Script -exitCode 1
}

# Check if branches are provided
if ($branches.Length -eq 0) {
    Write-Error -Message "No branches specified. Please provide branches to merge."
    Exit-Script -exitCode 1
}

# Check if main branch is provided
if (-not (git branch --list $mainBranch)) {
    Write-Error -Message "Main branch $mainBranch does not exist. Please provide a valid main branch."
    Exit-Script -exitCode 1
}

# Checkout and update the main branch
git checkout $mainBranch
git pull origin $mainBranch

# Merge the main branch into the first branch
Merge-Branch -targetBranch $branches[0] -sourceBranch $mainBranch

# Loop through branches and merge previous branch into current branch
for ($i = 1; $i -lt $branches.Length; $i++) {
    Merge-Branch -targetBranch $branches[$i] -sourceBranch $branches[$i - 1]
}

Write-Host "All branches updated successfully."

# Ask user if they want to push changes to remote repository
$push = Read-Host -Prompt "Do you want to push changes to the remote repository? (Y/N)"

if ($push -eq "Y" -or $push -eq "y") {
    # Iterate through branches and push changes to remote repository
    foreach ($branch in $branches) {
        git push origin $branch
    }

    if ($?) {
        Write-Host "Changes pushed to remote repository successfully."
    }
    else {
        Write-Error -Message "Failed to push changes to remote repository."
    }
}
else {
    Write-Host "Changes not pushed to remote repository. Check them locally and push them manually."
}

Exit-Script