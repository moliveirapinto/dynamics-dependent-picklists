. "$PSScriptRoot\dv.ps1"

# Build a minimal unmanaged solution zip that updates Case form XML.
$libraryName  = 'mau_DependentPicklistRuntime.js'
$functionName = 'MauDependentPicklists.onFormLoad'

$forms = @(
  @{ id='4a63c8d1-6c1e-48ec-9db4-3e6c7155334c'; name='Case' },
  @{ id='915f6055-2e07-4276-ae08-2b96c8d02c57'; name='Case for Interactive experience' }
)

$tmpRoot = Join-Path $env:TEMP ("DepPicklistFormPatch_" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
Write-Host "Working dir: $tmpRoot"

# --- Solution.xml ---
$solutionXml = @"
<ImportExportXml version="9.2.0.0" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="ApiPatch" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SolutionManifest>
    <UniqueName>DependentPicklists</UniqueName>
    <LocalizedNames>
      <LocalizedName description="Dependent Picklists" languagecode="1033" />
    </LocalizedNames>
    <Descriptions>
      <Description description="Dependent Picklists" languagecode="1033" />
    </Descriptions>
    <Version>1.0.0.1</Version>
    <Managed>0</Managed>
    <Publisher>
      <UniqueName>maulabs</UniqueName>
      <LocalizedNames>
        <LocalizedName description="Mau Labs" languagecode="1033" />
      </LocalizedNames>
      <Descriptions>
        <Description description="Mau Labs" languagecode="1033" />
      </Descriptions>
      <EMailAddress xsi:nil="true"></EMailAddress>
      <SupportingWebsiteUrl xsi:nil="true"></SupportingWebsiteUrl>
      <CustomizationPrefix>mau</CustomizationPrefix>
      <CustomizationOptionValuePrefix>10000</CustomizationOptionValuePrefix>
      <Addresses>
        <Address>
          <AddressNumber>1</AddressNumber>
          <AddressTypeCode>1</AddressTypeCode>
          <City xsi:nil="true"></City>
          <County xsi:nil="true"></County>
          <Country xsi:nil="true"></Country>
          <Fax xsi:nil="true"></Fax>
          <FreightTermsCode xsi:nil="true"></FreightTermsCode>
          <ImportSequenceNumber xsi:nil="true"></ImportSequenceNumber>
          <Latitude xsi:nil="true"></Latitude>
          <Line1 xsi:nil="true"></Line1>
          <Line2 xsi:nil="true"></Line2>
          <Line3 xsi:nil="true"></Line3>
          <Longitude xsi:nil="true"></Longitude>
          <Name xsi:nil="true"></Name>
          <PostalCode xsi:nil="true"></PostalCode>
          <PostOfficeBox xsi:nil="true"></PostOfficeBox>
          <PrimaryContactName xsi:nil="true"></PrimaryContactName>
          <ShippingMethodCode>1</ShippingMethodCode>
          <StateOrProvince xsi:nil="true"></StateOrProvince>
          <Telephone1 xsi:nil="true"></Telephone1>
          <Telephone2 xsi:nil="true"></Telephone2>
          <Telephone3 xsi:nil="true"></Telephone3>
          <TimeZoneRuleVersionNumber xsi:nil="true"></TimeZoneRuleVersionNumber>
          <UPSZone xsi:nil="true"></UPSZone>
          <UTCOffset xsi:nil="true"></UTCOffset>
          <UTCConversionTimeZoneCode xsi:nil="true"></UTCConversionTimeZoneCode>
        </Address>
        <Address>
          <AddressNumber>2</AddressNumber>
          <AddressTypeCode>1</AddressTypeCode>
          <City xsi:nil="true"></City>
          <County xsi:nil="true"></County>
          <Country xsi:nil="true"></Country>
          <Fax xsi:nil="true"></Fax>
          <FreightTermsCode xsi:nil="true"></FreightTermsCode>
          <ImportSequenceNumber xsi:nil="true"></ImportSequenceNumber>
          <Latitude xsi:nil="true"></Latitude>
          <Line1 xsi:nil="true"></Line1>
          <Line2 xsi:nil="true"></Line2>
          <Line3 xsi:nil="true"></Line3>
          <Longitude xsi:nil="true"></Longitude>
          <Name xsi:nil="true"></Name>
          <PostalCode xsi:nil="true"></PostalCode>
          <PostOfficeBox xsi:nil="true"></PostOfficeBox>
          <PrimaryContactName xsi:nil="true"></PrimaryContactName>
          <ShippingMethodCode>1</ShippingMethodCode>
          <StateOrProvince xsi:nil="true"></StateOrProvince>
          <Telephone1 xsi:nil="true"></Telephone1>
          <Telephone2 xsi:nil="true"></Telephone2>
          <Telephone3 xsi:nil="true"></Telephone3>
          <TimeZoneRuleVersionNumber xsi:nil="true"></TimeZoneRuleVersionNumber>
          <UPSZone xsi:nil="true"></UPSZone>
          <UTCOffset xsi:nil="true"></UTCOffset>
          <UTCConversionTimeZoneCode xsi:nil="true"></UTCConversionTimeZoneCode>
        </Address>
      </Addresses>
    </Publisher>
    <RootComponents>
      <RootComponent type="60" schemaName="$(($forms[0].id))" behavior="0" />
      <RootComponent type="60" schemaName="$(($forms[1].id))" behavior="0" />
    </RootComponents>
    <MissingDependencies />
  </SolutionManifest>
</ImportExportXml>
"@

# --- customizations.xml ---
function Build-FormSection($form) {
  $sf = Invoke-Dv -Method GET -Path "/api/data/v9.2/systemforms($($form.id))?`$select=name,formxml,type"
  [xml]$x = $sf.formxml
  # Add library
  $libs = $x.SelectSingleNode('/form/formLibraries')
  if (-not $libs) { $libs = $x.CreateElement('formLibraries'); $x.DocumentElement.PrependChild($libs) | Out-Null }
  if (-not $libs.SelectSingleNode("Library[@name='$libraryName']")) {
    $lib = $x.CreateElement('Library')
    $lib.SetAttribute('name', $libraryName)
    $lib.SetAttribute('libraryUniqueId', [Guid]::NewGuid().ToString('B'))
    $libs.AppendChild($lib) | Out-Null
  }
  # Add onload handler
  $events = $x.SelectSingleNode('/form/events')
  if (-not $events) { $events = $x.CreateElement('events'); $x.DocumentElement.AppendChild($events) | Out-Null }
  $onload = $events.SelectSingleNode("event[@name='onload']")
  if (-not $onload) {
    $onload = $x.CreateElement('event')
    $onload.SetAttribute('name','onload'); $onload.SetAttribute('application','false'); $onload.SetAttribute('active','false')
    $h = $x.CreateElement('Handlers'); $onload.AppendChild($h) | Out-Null
    $events.AppendChild($onload) | Out-Null
  }
  $handlers = $onload.SelectSingleNode('Handlers')
  if (-not $handlers.SelectSingleNode("Handler[@functionName='$functionName' and @libraryName='$libraryName']")) {
    $h = $x.CreateElement('Handler')
    $h.SetAttribute('functionName', $functionName)
    $h.SetAttribute('libraryName', $libraryName)
    $h.SetAttribute('handlerUniqueId', [Guid]::NewGuid().ToString('B'))
    $h.SetAttribute('enabled','true'); $h.SetAttribute('parameters',''); $h.SetAttribute('passExecutionContext','true')
    $handlers.AppendChild($h) | Out-Null
  }

  $formInner = $x.OuterXml
  return @"
<systemform unmodified="0">
  <formid>{$($form.id)}</formid>
  <IntroducedVersion>9.0.0.0</IntroducedVersion>
  $formInner
</systemform>
"@
}

$caseFormSec   = Build-FormSection $forms[0]
$ixCaseFormSec = Build-FormSection $forms[1]

$customizationsXml = @"
<ImportExportXml version="9.2.0.0" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="ApiPatch" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Entities>
    <Entity>
      <Name LocalizedName="Case" OriginalName="Case">incident</Name>
      <FormXml>
        <forms type="main">
          $caseFormSec
          $ixCaseFormSec
        </forms>
      </FormXml>
    </Entity>
  </Entities>
  <Templates></Templates>
  <EntityMaps></EntityMaps>
  <EntityRelationships></EntityRelationships>
  <OrganizationSettings></OrganizationSettings>
  <optionsets></optionsets>
  <Workflows></Workflows>
  <FieldSecurityProfiles></FieldSecurityProfiles>
  <Roles></Roles>
  <SdkMessageProcessingSteps></SdkMessageProcessingSteps>
  <ServiceEndpoints></ServiceEndpoints>
  <WebResources></WebResources>
  <Languages><Language>1033</Language></Languages>
</ImportExportXml>
"@

[System.IO.File]::WriteAllText((Join-Path $tmpRoot 'solution.xml'), $solutionXml, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $tmpRoot 'customizations.xml'), $customizationsXml, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $tmpRoot '[Content_Types].xml'), '<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/octet-stream" /></Types>', [System.Text.UTF8Encoding]::new($false))

$zipPath = Join-Path $env:TEMP ("DependentPicklists_FormPatch_$([Guid]::NewGuid().ToString('N')).zip")
if (Test-Path $zipPath) { Remove-Item $zipPath }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tmpRoot, $zipPath)
Write-Host "Solution zip: $zipPath" -ForegroundColor Cyan
Write-Host "Importing via pac..." -ForegroundColor Cyan
& pac solution import --path $zipPath --publish-changes --force-overwrite
