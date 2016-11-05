# SelfSigned-Cert-Creator
A short script to make it easy to create a viable, trusted self-signed certificate that can be used for SSL/TLS in particular.

# Quickstart

1. Run the script giving the web server's IP address/domain the parameter (e.g. 192.168.1.10, myweb.mydomain.com, *.mydomain.com).
2. Move the files in the `server` folder to a convenient location
3. Adjust your web server configuration to use the `privkey.pem` & `fullchain.pem` files
4. Upload the `client/my-private-root-ca.crt` to the certificate store on any device needing access to the server to get rid of untrusted root CA warnings.

# Background
The correct use of public key cryptography is a difficult and complex subject. And yet we are encouraged to ensure that **all** websites use HTTPS (TLS) to ensure that the transport between the server and clients is encrypted.

Certificates for HTTPS are also often very expensive to buy and update. Although there are a few low-cost certificate providers such as StartSSL and Lets Encrypt, you are trading the low cost for higher maintenance since the certificate lifetimes are short.

It is possible however to create your own certificates, so called self-signed. But the process is arcane even in 2016. Also, all browsers are gradually moving to a model that automatically rejects self-signed certificates, assuming that they are some kind of attack - which of course they can be - but generally are not. They are merely an attempt to develop new services or to keep down costs.

To use certificates to encrypt traffic from your server to clients, you need to provide two things. A *certificate* and a *private key*. The certificate can be freely published and you can let anyone have it. The private key, on the other hand, **must** be kept safe at all times, if someone gets a copy, it is worthless and you need to generate a new certificate & key.

# The script
The script offered here contains all the arcane wizardry to create not only a server certificate that will let you secure communications to client devices but also a stand-alone Certificate Authority (CA) that can be used for signing as many certificates as you like.

If you don't do anything on devices accessing your server, you will still get warnings saying that the certificate is untrusted. That is because all client devices using HTTPS contain a list of trusted root certificates. Any server certificate cross-signed by a trusted root CA will be trusted by the browser (a much bigger risk than using self-signed certs!). As your CA cert is not in the list, the device doesn't trust your servers certificate. This is easily fixed though, see the how-to-use section.

You only need to run the full script once. Thereafter, you don't need the CA lines because you already have a CA certificate and key.

The script will create a number of folders relative to the location of the script file: 
- `tmp` - deleted at the end of the script
- `ca` - contains the CA related files - **must be kept secure**, best kept offline until needed next time
- `server` - the certificate and key files required by the server to work over HTTPS, move to a convenient location
- `client` - files to help clients trust your self-signed certificate, see the how-to-use section

The script is a BASH command line script so only works on a Linux command prompt and requires OpenSSL which virtually all current versions of Linux already have installed. The script also works on the Windows 10 Ubuntu subsystem.

## Running
To run the script, you need to be at a BASH command prompt and you need to supply either a domain specification or an IP address. That address will be baked into the certificate and the certificate will only be valid when used on that address:

    ./certs.sh 192.168.1.10

This example creates a server certificate (and corresponding CA) that is valid for a server access on IP address `192.168.1.10`, the certificate would not be valid if used on `myserver.mydomain.com` for example.

# How to use the output
The server certificate and key can be used with any software that provides a web server. That includes Apache, NGINX, Node.JS, Python, etc.

The important files are put into the `server` folder and are:

- `privkey.pem` - This is the servers private key file. It **must** be kept secure on the server.
- `fullchain.pem` - This is the servers certificate file. It will be sent to any connected client and does not need to be kept particularly secure. It not only contains the server certificate but also the CA certificate so that the browser is able to validate the chain. Note that the browser will still dislike the certificate until you add the CA cert to the appropriate trusted root CA store (see below).

## Using with [Node.JS](https://nodejs.org)
Here is an example of the options to need to pass to the [HTTPS create server function](https://nodejs.org/dist/latest-v6.x/docs/api/https.html#https_https_createserver_options_requestlistener). Adjust according to wherever you put the server key and certificate files.

    const options = {
      key: fs.readFileSync( path.join('.', '.data', 'certs', 'server', 'privkey.pem') ),
      cert: fs.readFileSync( path.join('.', '.data', 'certs', 'server', 'fullchain.pem') )
    };

Note that you do not need the `ca` option and that you need to use the `server/fullchain.pem` file not just the `server/cert.pem` file otherwise the certificate will not be valid.

## Using with [Node-RED](https://nodered.org)
Here is an example of the code that you will need to add to your settings.js file for Node-RED. Take note of the joined paths and adjust according to where you moved the server key and certificate files to.

    module.exports = {
      ...
      https: {
        key: fs.readFileSync( path.join('.', '.data', 'certs', 'server', 'privkey.pem') ),
        cert: fs.readFileSync( path.join('.', '.data', 'certs', 'server', 'fullchain.pem') )
      },
      ....
    }

## Using on a Windows client
To get rid of any browser warnings, you must load the CA certificate into a position of trust.

Copy the file `client/my-private-root-ca.crt` to the Windows PC. Right-click and choose `Install Certificate`. Choose whether you want this for just the current user or for all users of this PC (Local Machine, You will need local admin rights for this). On the next stage, choose "Place all certificates in the following store" and click the browse button. Choose "Trusted Root Certification Authorities" and click OK. Continuing should result in a message that the certificate as been successfully installed.

Restart your browser and any certificate errors when connecting to your server should now have gone away. This works for Edge, Internet Explorer and Chrome. 

Firefox has its own certificate store. It is also the only browser where you can add a permanent exception to certificate warnings. But if you want to fix it properly, Go to Options, Advanced, Certificates. Click on View Certificates, Import. Select "Trust this CA to identify web sites". You will at least need to open a new tab if you already had the site open.

## Using on mobile client devices
Firstly, you will need to make the root CA certificate available. You can either drop it in an email to yourself or serve it via a convenient web server, or put it in cloud storage. As you are only making the certificate available (which can be public), it doesn't matter if someone else gets hold of it.

...tbc...

## Other uses
Although this has focused on using the certificate/key for HTTPS. It is possible to use the same details for other purposes such as encrypting emails or files and signing code.

For example, there is a server public key file in the `client` folder. This can be used with appropriate software (*need ref*) to encrypt data that the server could decrypt or visa versa.

## Reusing the CA
If you keep the CA folder and contents safe, you can reuse the files when creating new server certificates in the future. Simply put the folder and contents back under the script files location and comment out the lines that relate to creating the CA details.

# Security
It is very important that the files in the CA folder are kept totally secure. If they are compromised, all of the certificates that have been signed by the CA cert will be suspect and will have to be replaced.

Similarly, any private key file absolutely must be kept secure or will be considered compromised.

# License
This code is Open Source under an Apache 2 License. Please see the apache2-license.txt file for details.

You may not use this code except in compliance with the License. You may obtain an original copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
    
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. Please see the License for the specific language governing permissions and limitations under the License.

# Author
[Julian Knight](https://uk.linkedin.com/in/julianknight2/) ([Totally Information](https://www.totallyinformation.com)), https://github.com/totallyinformation

# Feedback and Support
Please report any issues or suggestions via the [Github Issues list for this repository](https://github.com/TotallyInformation/SelfSigned-Cert-Creator/issues).
