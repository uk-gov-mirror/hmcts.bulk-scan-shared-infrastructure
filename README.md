# bulk-scan-shared-infrastructure

This module sets up the shared infrastructure for Bulk Scanning. It also provides the ability to run CCD locally in docker containers..

## Variables

### Configuration

The following parameters are required by this module

- `env` The environment of the deployment, such as "prod" or "sandbox".
- `tenant_id` The Azure Active Directory tenant ID that should be used for authenticating requests to the key vault.
- `jenkins_AAD_objectId` The Azure AD object ID of a user, service principal or security group in the Azure Active Directory tenant for the vault.

The following parameters are optional

- `product` The (short) name of the product. Default is "bulk-scan". 
- `location` The location of the Azure data center. Default is "UK South".
- `application_type` Type of Application Insights (Web/Other). Default is "Web".

### Output

- `appInsightsInstrumentationKey` The instrumentation key for the application insights instance.
- `vaultName` The name of the key vault.

### Testing

Changes to this project will be run against the preview environment if a PR is open and the PR is prefixed with [PREVIEW]

### CCD Docker Setup
#### Prerequisites

* [Docker](https://www.docker.com/)
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [jq](https://stedolan.github.io/jq/)
* (*Optional*) To upload documents to document management store(dm-store) and allow CCD to talk to local document store add below entry in host file.

```
127.0.0.1 dm-store
```

#### Steps to start ccd management web

Execute below script to start ccd locally.

  ```bash
  $ ./bin/start-ccd-web.sh
  ```
  
After doing any git pull on this repo you should rebuild the containers:
```bash
 $ docker-compose build
```

This will:
- start ccd and dependent services locally
- mount database volumes, to which your data will persist between restarts,
- expose container ports to the host, so all the APIs and databases will be directly accessible. Use `docker ps` or read the [compose file](./docker-compose.yml) to see how the ports are mapped.
- load the idam user, roles and services required
- load the ccd definition
- enable ccd caseworkers:
  - default (see below)
  - personal hmcts one

To stop the environment use the same script, just make sure to pass the `local` parameter:

```bash
$ ./bin/stop-environment.sh
```
  
User for local development:

- username: `bulkscan+ccd@gmail.com`
- password: `Password12`

####  CCD definition

In order to upload the new definition file, put the definition file at location 
`docker/ccd-definition-import/data/CCD_Definition_BULK_SCAN.template.xlsx`

Make sure the caseworker created in the above step is configured in the UserProfile tab of the definition file and has correct roles.

#### Uploading CCD definition

```bash
$ ./bin/upload-ccd-spreadsheet.sh
```

#### Debugging

If an error occurs try running the script with a `-v` flag after the script name

```bash
$ ./bin/upload-ccd-spreadsheet.sh -v
```

#### Login into CCD

Open management web page http://localhost:3451 and login with user created above

#### Troubleshooting docker setup

##### Start CCD Web script fails on first run

IdAM API takes a long time to boot up.
This causes incomplete docker setup.
Inspect `docker ps -a` idam container, wait for completion, then run `./bin/start-ccd-web.sh` again.
In all occasions never experienced a failure afterwards

##### CCD Web is up and running, but cannot log in

There can be multiple reasons including core breaking changes introduced by services enlisted in `docker-compose config --servives`.

The first course of action is to check whether CCD definition got imported successfully as it is creating user profiles which are mandatory for login

The following are suggestions of possible culprits:

- role mismatch between idam and ccd. Check both `ccd-importer` and `idam-importer`
- debug down the line from `ccd-case-management-web`
- check configuration/environment variables

### Publishing message to Service Bus Queue

Azure does not provide emulator to spin up Service Bus Queue locally; hence you will have to always use an instance deployed on one of the environments (Sandbox, Demo or AAT).

To publish message to queue follow below steps.

* Make a curl request in below format.

  ```bash
  $ curl -X POST https://<namespace>-<env>.servicebus.windows.net/<entityPath>/messages -H "Authorization: <SharedAccessSignature>" -H "Content-Type:application/json" -d "{"envelopeId":"12344"}" -i
  ```
  
_**namespace**_ : namespace of the service bus for e.g on AAT namespace would be `bulk-scan-servicebus-aat`

_**entityPath**_ : name of the queue for e.g envelopes(this will not change with environment)

_**SharedAccessSignature**_ : For details check [Service Bus SAS](https://docs.microsoft.com/en-us/azure/service-bus-messaging/service-bus-sas)

To generate Shared signature locally, you can use the below code snippet.

```java
import java.net.URLEncoder;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

public class GetSASToken {

    public static void main(String[] args) throws Exception {

        String sas = getSASToken("<Service Bus URI>",
            "<Key Name>",
            "<Key Value>");

        System.out.println(sas);
    }

    private static String getSASToken(String resourceUri, String keyName, String key) throws Exception {
        long epoch = System.currentTimeMillis() / 1000L;
        int week = 60 * 60 * 24 * 7;
        String expiry = Long.toString(epoch + week);

        String stringToSign = URLEncoder.encode(resourceUri, "UTF-8") + "\n" + expiry;
        String signature = getHMAC256(key, stringToSign);
        return "SharedAccessSignature sr=" + URLEncoder.encode(resourceUri, "UTF-8") + "&sig=" +
            URLEncoder.encode(signature, "UTF-8") + "&se=" + expiry + "&skn=" + keyName;
    }


    public static String getHMAC256(String key, String input) throws Exception {
        Mac sha256HMAC = Mac.getInstance("HmacSHA256");
        SecretKeySpec secretKey = new SecretKeySpec(key.getBytes(), "HmacSHA256");
        sha256HMAC.init(secretKey);
        Base64.Encoder encoder = Base64.getEncoder();

        return new String(encoder.encode(sha256HMAC.doFinal(input.getBytes("UTF-8"))));
    }
}
```

* **_Service Bus URI_** : URI of the service bus for e.g on AAT it will be `https://bulk-scan-servicebus-aat.servicebus.windows.net/`
* **_Key name and Key Value_** : Needs to be retrieved from portal.
Search for service bus namespace in portal and then navigate to the queue where message needs to be sent.
Click on shared access policies and then select the policy(key for e.g SendSharedAccessKey) where claim is configured to have value Send. 

#### Some nice things to know

* Allocate enough memory to docker to spin up all the containers. 6 GB would be recommended - transition to sidam made sure enough RAM will be consumed.

* You can pass flags while creating docker container for e.g to recreate all containers from scratch.

  ```bash
  $ ./bin/start-ccd-web.sh --force-recreate
  ```
  
* You can delete all containers by executing below command.

 ```bash
  $ docker rm $(docker ps -a -q)
  ```
  
* You can remove all images by executing below command.

 ```bash
  $ docker rmi $(docker images -q)
  ```
  
* To list all volumes created run below command.

```bash
  $ docker volume ls
 ```
  
* In case you want to remove docker volumes to destroy database volume mount run below command.

 ```bash
  $ docker volume rm <volume name>
  ```

