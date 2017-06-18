#import cert chain
# @see last answer at https://social.technet.microsoft.com/Forums/en-US/8e016573-9191-4152-8c4e-b74d739f5894/powershell-to-add-a-certificate-to-trusted-root-certification-authorities?forum=winserverpowershell

$p7b = '\\dc2012\CertEnroll\FoxDeployCAChain.p7b'
Import-Certificate -FilePath $p7b -CertStoreLocation Cert:\LocalMachine\Root
