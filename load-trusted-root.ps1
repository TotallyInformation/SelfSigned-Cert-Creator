#import cert chain
# @see https://technet.microsoft.com/en-us/itpro/powershell/windows/pkiclient/import-certificate
# @see last answer at https://social.technet.microsoft.com/Forums/en-US/8e016573-9191-4152-8c4e-b74d739f5894/powershell-to-add-a-certificate-to-trusted-root-certification-authorities?forum=winserverpowershell

$myTrustedCertChain = '.\certs\client\my-private-root-ca.crt'
Import-Certificate -FilePath $myTrustedCertChain -CertStoreLocation Cert:\LocalMachine\Root
