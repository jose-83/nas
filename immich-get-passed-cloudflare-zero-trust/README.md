## Can't get past ClouldFlare Zero Trust on Mobile? Do THIS!

From this [video](https://youtu.be/J4vVYFVWu5Q?si=ksUlOl3G9cFIDqy-).

### Adding Zero Trust Access Layer 
Cloudflare > Zero Trust > Access Controls > Applications

Add an application > Self-hosted

Then, subdomain as `photos` and domain as `sabri.life`.

We need to create policies and add them to this application. In our case we have an email policy 
which allows my emails and Maryam's email.

We need to have a policy as `immich mobile app` that bypasses the credentials for our app.
We need to create a service token here: Access Controls > Service Credentials > Service Tokens

And create a new one. We need to note `access-client-id` and `access-client-id-secret.`

In the policy, we need to give it a name as `immich mobile app` then set `Action` as `Bypass`. 
Then, we need to add a rule and it should include our created service token. 

### Configuring Mobile App
On immich mobile app go to: settings > Advanced > Custom Proxy Headers and add two inputs:

`CF-Access-Client-Id` and its value as well as `CF-Access-Client-Secret` and its value. 
Now, if you change the url value to your subdomain.domain.com here: photos.sabri.life there will be no problem.

### Networking: Switching URLs
In Settings > Networking > Activate Automatic URL Switching

Then, click on USE CURRENT CONNECTION and in the EXTERNAL NETWORK, add `https://photos.sabri.life`. and it should work fine.

Be aware that if you update your app or logout, you need to repeat this last step for switching URL :(