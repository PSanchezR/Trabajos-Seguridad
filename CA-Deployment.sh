#!/bin/bash


#Creación de estructura de carpetas, índice , etc.
cd /root/ca
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

#Copia del fichero de configuración de la ca
cp ./root_cnf/openssl.cnf /root/ca 

#Creación de clave de root

openssl genrsa -aes256 -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

openssl req -config openssl.cnf -key private/ca.key.pem -new -x509 -days 7300 -sha256 -extensions v3_ca -out certs/ca.cert.pem

chmod 444 certs/ca.cert.pem

openssl x509 -noout -text -in certs/ca.cert.pem

#------------------------------#
#Creación de estructuras para certificado intermedio

mkdir /root/ca/intermediate
cd /root/ca/intermediate
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 1000 > /root/ca/intermediate/crlnumber
cd /root/ca

#Copia del fichero de configuración de la ca intermedia
cp /root/ca/intermediate_cnf/openssl.cnf /root/ca/intermediate 

#Creación de las claves del certificado intermedio
openssl genrsa -aes256 -out intermediate/private/intermediate.key.pem 4096
chmod 400 intermediate/private/intermediate.key.pem

#Creación de certificado intermedio (Cambiar los datos del certificado en -subj por los reales)
openssl req -config intermediate/openssl.cnf -new -sha256 -key intermediate/private/intermediate.key.pem -out intermediate/csr/intermediate.csr.pem
cd /root/ca
openssl ca -config openssl.cnf -extensions v3_intermediate_ca  -days 3650 -notext -md sha256 -in intermediate/csr/intermediate.csr.pem -out intermediate/certs/intermediate.cert.pem -subj "/C=ES/CN=ES/ST=ES/O=ES"
chmod 444 intermediate/certs/intermediate.cert.pem

#Comprobación del certificado

openssl verify -CAfile certs/ca.cert.pem intermediate/certs/intermediate.cert.pem

#Creación del archivo de cadena de certificados

cat intermediate/certs/intermediate.cert.pem certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem

chmod 444 intermediate/certs/ca-chain.cert.pem


#------------------------------#

#Firmar certificados de servidor y cliente

#Creando una llave

cd /root/ca
openssl genrsa -aes256 -out intermediate/private/www.example.com.key.pem 2048
chmod 400 intermediate/private/www.example.com.key.pem

#Crear un certificado

cd /root/ca
openssl req -config intermediate/openssl.cnf -key intermediate/private/www.example.com.key.pem -new -sha256 -out intermediate/csr/www.example.com.csr.pem

openssl ca -config intermediate/openssl.cnf -extensions server_cert -days 375 -notext -md sha256 -in intermediate/csr/www.example.com.csr.pem -out intermediate/certs/www.example.com.cert.pem -subj "/C=ES/CN=ES/ST=ES/O=ES"

chmod 444 intermediate/certs/www.example.com.cert.pem

#Comprobación del certificado
openssl x509 -noout -text -in intermediate/certs/www.example.com.cert.pem

openssl verify -CAfile intermediate/certs/ca-chain.cert.pem intermediate/certs/www.example.com.cert.pem

#Para desplegar el certificado se tienen los archivos ca_chain.cert.pem, www.example.com.key.pem y www.example.com.cert.pem


#------------------------------#

#Listas de revocación de certificados

#Crear la CRL
openssl ca -config intermediate/openssl.cnf -gencrl -out intermediate/crl/intermediate.crl.pem
openssl crl -in intermediate/crl/intermediate.crl.pem -noout -text


#Creamos la clave de "Bob"

mkdir /home/bob
openssl genrsa -out /home/bob/bob@example.com.key.pem 2048
openssl req -new -key /home/bob/bob@example.com.key.pem -out /home/bob/bob@example.com.csr.pem


#"Bob" envía a "Alice" su certificado para que lo firme y lo compruebe
cp /home/bob/bob@example.com.csr.pem /root/ca/intermediate/csr/
sleep 1 
openssl ca -config /root/ca/intermediate/openssl.cnf -extensions usr_cert -notext -md sha256 -in /root/ca/intermediate/csr/bob@example.com.csr.pem -out /root/ca/intermediate/certs/bob@example.com.cert.pem
openssl verify -CAfile /root/ca/intermediate/certs/ca-chain.cert.pem intermediate/certs/bob@example.com.cert.pem

#Creamos la clave de "Eve"

mkdir /home/eve
openssl genrsa -out /home/eve/eve@example.com.key.pem 2048
openssl req -new -key /home/eve/eve@example.com.key.pem -out /home/eveeve@example.com.csr.pem

#"Eve" envía a "Alice" su certificado para que lo firme y lo compruebe
cp /home/eve/eve@example.com.csr.pem /root/ca/intermediate/csr/
sleep 1 
openssl ca -config /root/ca/intermediate/openssl.cnf -extensions usr_cert -notext -md sha256 -in /root/ca/intermediate/csr/eve@example.com.csr.pem -out /root/ca/intermediate/certs/eve@example.com.cert.pem
openssl verify -CAfile /root/ca/intermediate/certs/ca-chain.cert.pem /root/ca/intermediate/certs/eve@example.com.cert.pem


#Ejemplo de revocación
cd /root/ca
openssl ca -config intermediate/openssl.cnf -revoke intermediate/certs/bob@example.com.cert.pem

