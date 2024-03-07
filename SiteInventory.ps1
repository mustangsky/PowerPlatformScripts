#Load SharePoint Online Assemblies
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
   
##Variables for Processing
$SiteUrl = ""
$UserName=""
$Password =""
  
#Setup Credentials to connect
$Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($UserName,(ConvertTo-SecureString $Password -AsPlainText -Force))

#Process Site
Function Get-SPOWeb() {
param(
    $WebURL = $(throw "Please Enter the Site Collection URL"),
    $Data
)
 
    #Get Web information and subsites
    $Context = New-Object Microsoft.SharePoint.Client.ClientContext($WebURL)
    $Context.Credentials = $credentials
    $Web = $context.Web
    $Context.Load($Web)
 
    #powershell cmdlet to retrieve sharepoint online subsites
    $Context.Load($Web.Webs) 
    $Context.Load($Web.Lists) 
    $Context.executeQuery()
    
    Write-host $Web.URL

    #add current site
    $Data += [PSCustomObject]@{ Type = "Site"; SiteUrl = $WebURL; ListName = ""; ListItemId = ""; ModifiedDate = ""; LastItemModifiedDate = $Web.LastItemModifiedDate; LastItemUserModifiedDate = $Web.LastItemUserModifiedDate}
    foreach ($list in $Web.Lists)
    {
        Write-host $list.Title

        #add current list
        $Data += [PSCustomObject]@{ Type = "List"; SiteUrl = $WebURL; ListName = $list.Title; ListItemId = ""; ModifiedDate = ""; LastItemModifiedDate = $list.LastItemModifiedDate; LastItemUserModifiedDate = $list.LastItemUserModifiedDate }
        
        #get all list items
        $Data = Get-SPOListItems -WebURL $WebURL -Context $Context -List $list -Data $Data
        
    }
    
    #Iterate through each subsite in the current web
    foreach ($Subweb in $Web.Webs)
    {
        #Call the function recursively to process all subsites underneath the current web
        $Data = Get-SPOWeb  -WebURL $Subweb.url -Data $Data
    }
    return $Data
    
}

#Process list
Function Get-SPOListItems() {
param(
    $WebURL = $(throw "Please Enter the web URL"),
    $Context,
    $List,
    $Data
)

    #$List = $Context.web.Lists.GetByTitle($ListTitle)
    $ListItems = $List.GetItems([Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery()) 
    $Context.Load($ListItems)
    $Context.ExecuteQuery()

    #Iterate through each listitems
    foreach ($item in $ListItems)
    {
        #add list item
        $Data += [PSCustomObject]@{ Type = "ListItem"; SiteUrl = $WebURL; ListName = $List.Title; ListItemId = $item.ID; ModifiedDate = $item.FieldValues["Modified"]; LastItemModifiedDate = ""; LastItemUserModifiedDate = "" }
    }
    return $Data
}

#Call the function
$FileData = Get-SPOWeb -WebURL $SiteUrl -Data @()
$FileData | Export-Csv -Path ".\SiteInventory.csv" -NoTypeInformation