Import-Module ActiveDirectory

############################################ --- Scripte1: Création de l'OU racine ---  #########################################
$racinePath = "DC=esgi,DC=local"
$laFiliale = "LaFiliale"

if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$laFiliale'" -SearchBase $racinePath -ErrorAction SilentlyContinue)) {
    try {
        New-ADOrganizationalUnit -Name $laFiliale -Path $racinePath -ProtectedFromAccidentalDeletion $true
        Write-Host "OU racine créée : $laFiliale"
    } catch {
        Write-Host "Erreur lors de la création de l'OU racine '$laFiliale' : $_"
    }
} else {
    Write-Host "OU racine déjà existante : $laFiliale"
}

########################## --- Création des OU et Sous-OU ---
$csvpath = ".\OUCreation.csv"
$ou = Import-Csv -Path $csvpath -Delimiter ";"

foreach ($o in $ou) {
    # Création de l'OU principale
    try {
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$($o.name)'" -SearchBase $o.path -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $o.name -Path $o.path -ProtectedFromAccidentalDeletion $true
            Write-Host "OU principale créée : $($o.name)"
        } else {
            Write-Host "OU principale déjà existante : $($o.name)"
        }
    } catch {
        Write-Host "Erreur lors de la création de l'OU principale '$($o.name)' : $_"
    }

    # Création des sous-OU
    $sou = $o.namesubOU -split ":"

    foreach ($s in $sou) {
        try {
            if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$s'" -SearchBase $o.PathsubOU -ErrorAction SilentlyContinue)) {
                New-ADOrganizationalUnit -Name $s -Path $o.PathsubOU -ProtectedFromAccidentalDeletion $true
                Write-Host "Sous-OU créée : $s"
            } else {
                Write-Host "Sous-OU déjà existante : $s"
            }
        } catch {
            Write-Host "Erreur lors de la création de la sous-OU '$s' dans '$($o.PathsubOU)' : $_"
        }
    }
}


Import-Module ActiveDirectory

##################################################### --- Script 2 : Création des utilisateurs --- #####################################################
$usersPath = ".\UsersLaFiliale.csv"
$users = Import-Csv -Path $usersPath -Delimiter ";"

foreach ($user in $users) {
    try {
        New-ADUser -Name $user.firstname `
                   -GivenName $user.firstname `
                   -Surname $user.lastname `
                   -OfficePhone $user.phone `
                   -Path $user.pathuser `
                   -Title $user.function `
                   -AccountPassword (ConvertTo-SecureString "Pa55Word" -AsPlainText -Force) `
                   -ChangePasswordAtLogon $true `
                   -Enabled $true `
                   -ErrorAction Stop

        Write-Host "Utilisateur créé : $($user.firstname) $($user.lastname)"
    } catch {
        Write-Host "Erreur lors de la création de l'utilisateur '$($user.firstname) $($user.lastname)' : $_"
    }
}




Import-Module ActiveDirectory

################################################ --- Script 3 : Suppression des utilisateurs #######################################

$usersPath = ".\usersToSupress.csv"

# Importation des données du CSV
$usersToDelete = Import-Csv -Path $usersPath -Delimiter ";"

# Traitement de chaque ligne
foreach ($entry in $usersToDelete) {
    $nom = $entry.nom
    $ou = $entry.localisation
    $aSupprimer = $entry.aSupprimer

    if ($aSupprimer -eq "O") {
        # Chercher les utilisateurs avec le nom dans l'OU
        try {
            $users = Get-ADUser -Filter "Name -like '*$nom*'" -SearchBase $ou
            if ($users.Count -eq 0) {
                Write-Host "Aucun utilisateur trouvé avec le nom '$nom' dans '$ou'"
            } else {
                foreach ($user in $users) {
                    Write-Host "Suppression de : $($user.SamAccountName) ($($user.DistinguishedName))"
                    Remove-ADUser -Identity $user -Confirm:$false
                }
            }
        } catch {
            Write-Host "Erreur lors de la recherche dans l'OU : $ou"
        }
    } else {
        Write-Host "Utilisateur '$nom' marqué comme à conserver (aSupprimer=N)"
    }
}

################################################ --- Scripte 4 : Désactivation des utilisateurs dans certaines OUs ############################################

$ouDisableCsvPath = ".\OUdisable.csv"
$ouListDisable = Import-Csv -Path $ouDisableCsvPath

foreach ($entry in $ouListDisable) {
    $ou = $entry.ou
    try {
        $users = Get-ADUser -Filter * -SearchBase $ou
        foreach ($user in $users) {
            Disable-ADAccount -Identity $user.SamAccountName
            Write-Host "Utilisateur désactivé : $($user.SamAccountName)"
        }
    } catch {
        Write-Host "Erreur lors de la désactivation dans l'OU : $ou"
    }
}

################################################ --- Vérification de suppression

$utilisateurs = @(
    @{Nom="paris"; OU="OU=Développement,OU=Recherche,OU=LaFiliale,DC=esgi,DC=local"},
    @{Nom="shiny"; OU="OU=Direction,OU=Services,OU=LaFiliale,DC=esgi,DC=local"},
    @{Nom="sad";   OU="OU=Comptabilité,OU=Services,OU=LaFiliale,DC=esgi,DC=local"}
)

foreach ($utilisateur in $utilisateurs) {
    $nom = $utilisateur.Nom
    $ou = $utilisateur.OU

    try {
        $user = Get-ADUser -Filter "Name -like '*$nom*'" -SearchBase $ou -Properties Enabled
        if ($user) {
            if ($user.Enabled -eq $true) {
                Write-Host "Utilisateur activé : $($user.Name) dans l'OU $ou"
            } else {
                Write-Host "Utilisateur DÉSACTIVÉ : $($user.Name) dans l'OU $ou"
            }
        } else {
            Write-Host "Aucun utilisateur avec le nom '$nom' trouvé dans l'OU $ou"
        }
    } catch {
        Write-Host "Erreur lors de la vérification dans l'OU : $ou"
    }
}

################################################ --- Désactivation des utilisateurs dans l'Usine

$ouUsine = "OU=Usine,OU=Production,OU=LaFiliale,DC=esgi,DC=local"
try {
    $usersUsine = Get-ADUser -Filter * -SearchBase $ouUsine
    foreach ($user in $usersUsine) {
        Disable-ADAccount -Identity $user.SamAccountName
        Write-Host "Utilisateur désactivé : $($user.SamAccountName)"
    }
} catch {
    Write-Host "Erreur lors de la désactivation dans l'OU Usine : $ouUsine"
}

