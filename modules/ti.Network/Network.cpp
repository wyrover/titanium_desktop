/*
 * Copyright (c) 2008-2010 Appcelerator, Inc. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "Network.h"

#include <sstream>

#include "Host.h"
#include "HTTPClient.h"
#include "HTTPServer.h"
#include "Interface.h"
#include "IPAddress.h"
#include "IRCClient.h"
#include "NetworkStatus.h"
#include "TCPServerSocket.h"
#include "TCPSocket.h"

#include <kroll/kroll.h>
#include <Poco/Mutex.h>
#include <Poco/Net/NetworkInterface.h>

using namespace Poco::Net;

namespace Titanium {

static KListRef interfaceList(0);
static std::string firstIPv4Address = "127.0.0.1";

static void GetInterfaceList()
{
    if (!interfaceList.isNull())
        return;

    interfaceList = new StaticBoundList();
    std::vector<NetworkInterface> list = NetworkInterface::list();
    for (size_t i = 0; i < list.size(); i++)
    {
        NetworkInterface& interface = list[i];
        interfaceList->Append(Value::NewObject(new Interface(interface)));

        if (!interface.address().isLoopback() &&
            interface.address().isIPv4Compatible())
            firstIPv4Address = interface.address().toString();
    }
}

Network::Network()
    : KAccessorObject("Network")
    , global(kroll::Host::GetInstance()->GetGlobalObject())
{
    GetInterfaceList();
    KValueRef online = Value::NewBool(true);

    /**
     * @tiapi(property=True,name=Network.online,since=0.2)
     * @tiapi Whether or not the system is connected to the internet
     * @tiresult[Boolean] True if the system is connected to the internet, false if otherwise
     */
    this->Set("online", online);

    // methods that are available on Titanium.Network
    /**
     * @tiapi(method=True,name=Network.createTCPSocket,since=0.2) Creates a TCPSocket object
     * @tiarg(for=Network.createTCPSocket,name=host,type=String) the hostname to connect to
     * @tiarg(for=Network.createTCPSocket,name=port,type=Number) the port to use
     * @tiresult(for=Network.createTCPSocket,type=Network.TCPSocket) a TCPSocket object
     */
    this->SetMethod("createTCPSocket",&Network::_CreateTCPSocket);
    /**
     * @tiapi(method=True,name=Network.createTCPServerSocket,since=1.2) Creates a TCPServerSocket object
     * @tiarg(for=Network.createTCPServerSocket,name=callback,type=Function) the callback to receive a new connection
     * @tiresult(for=Network.createTCPServerSocket,type=Network.TCPServerSocket) a TCPServerSocket object
     */
    this->SetMethod("createTCPServerSocket",&Network::_CreateTCPServerSocket);
    /**
     * @tiapi(method=True,name=Network.createIRCClient,since=0.2) Creates an IRCClient object
     * @tiresult(for=Network.createIRCClient,type=Network.IRCClient) an IRCClient object
     */
    this->SetMethod("createIRCClient",&Network::_CreateIRCClient);
    /**
     * @tiapi(method=True,name=Network.createIPAddress,since=0.2) Creates an IPAddress object
     * @tiarg(for=Network.createIPAddress,name=address,type=String) the IP address
     * @tiresult(for=Network.createIPAddress,type=Network.IPAddress) an IPAddress object
     */
    this->SetMethod("createIPAddress",&Network::_CreateIPAddress);
    /**
     * @tiapi(method=True,name=Network.createHTTPClient,since=0.3) Creates an HTTPClient object
     * @tiresult(for=Network.createHTTPClient,type=Network.HTTPClient) an HTTPClient object
     */
    this->SetMethod("createHTTPClient",&Network::_CreateHTTPClient);
    /**
     * @tiapi(method=True,name=Network.createHTTPServer,since=0.4) Creates an HTTPServer object
     * @tiresult(for=Network.createHTTPServer,type=Network.HTTPServer) a HTTPServer object
     */
    this->SetMethod("createHTTPServer",&Network::_CreateHTTPServer);
    /**
     * @tiapi(method=True,name=Network.createHTTPCookie,since=0.7) Creates a new HTTPCookie object
     * @tiresult(for=Network.createHTTPCookie,type=Network.HTTPCookie) a HTTPCookie object
     */
    this->SetMethod("createHTTPCookie",&Network::_CreateHTTPCookie);
    /**
     * @tiapi(method=True,name=Network.getHostByName,since=0.2) Returns a Host object using a hostname
     * @tiarg(for=Network.getHostByName,name=name,type=String) the hostname
     * @tiresult(for=Network.getHostByName,type=Network.Host) a Host object referencing the hostname
     */
    this->SetMethod("getHostByName",&Network::_GetHostByName);
    /**
     * @tiapi(method=True,name=Network.getHostByAddress,since=0.2) Returns a Host object using an address
     * @tiarg(for=Network.getHostByAddress,name=address,type=String) the address
     * @tiresult(for=Network.getHostByAddress,type=Network.Host) a Host object referencing the address
     */
    this->SetMethod("getHostByAddress",&Network::_GetHostByAddress);
    /**
     * @tiapi(method=True,name=Network.encodeURIComponent,since=0.3) Encodes a URI Component
     * @tiarg(for=Network.encodeURIComponent,name=value,type=String) value to encode
     * @tiresult(for=Network.encodeURIComponent,type=String) the encoded value
     */
    this->SetMethod("encodeURIComponent",&Network::_EncodeURIComponent);
    /**
     * @tiapi(method=True,name=Network.decodeURIComponent,since=0.3) Decodes a URI component
     * @tiarg(for=Network.decodeURIComponent,name=value,type=String) value to decode
     * @tiresult(for=Network.decodeURIComponent,type=String) the decoded value
     */
    this->SetMethod("decodeURIComponent",&Network::_DecodeURIComponent);

    /**
     * @tiapi(method=True,name=Network.addConnectivityListener,since=0.2)
     * @tiapi Adds a connectivity change listener that fires when the system
     * @tiapi connects or disconnects from the internet
     * @tiarg(for=Network.addConnectivityListener,type=Function,name=listener) 
     * @tiarg A callback method to be fired when the system connects or disconnects from the internet
     * @tiresult(for=Network.addConnectivityListener,type=Number) a callback id for the event
     */
    this->SetMethod("addConnectivityListener",&Network::_AddConnectivityListener);
    /**
     * @tiapi(method=True,name=Network.removeConnectivityListener,since=0.2) Removes a connectivity change listener
     * @tiarg(for=Network.removeConnectivityListener,type=Number,name=id) the callback id of the method
     */
    this->SetMethod("removeConnectivityListener",&Network::_RemoveConnectivityListener);

    /**
     * @tiapi(method=True,name=Network.setHTTPProxy,since=0.7)
     * @tiapi Override application proxy autodetection with a proxy URL.
     * @tiarg[String, hostname] The full proxy hostname.
     */
    this->SetMethod("setHTTPProxy", &Network::_SetHTTPProxy);
    this->SetMethod("setProxy", &Network::_SetHTTPProxy);

    /**
     * @tiapi(method=True,name=Network.getHTTPProxy,since=0.7) 
     * @tiapi Return the proxy override, if one is set.
     * @tiresult[String|null] The full proxy override URL or null if none is set.
     */
    this->SetMethod("getHTTPProxy", &Network::_GetHTTPProxy);
    this->SetMethod("getProxy", &Network::_GetHTTPProxy);

    /**
     * @tiapi(method=True,name=Network.setHTTPSProxy,since=0.7)
     * @tiapi Override application proxy autodetection with a proxy URL.
     * @tiarg[String, hostname] The full proxy hostname.
     */
    this->SetMethod("setHTTPSProxy", &Network::_SetHTTPSProxy);

    /**
     * @tiapi(method=True,name=Network.getHTTPSProxy,since=0.7)
     * @tiapi Return the proxy override, if one is set.
     * @tiresult[String|null] The full proxy override URL or null if none is set.
     */
    this->SetMethod("getHTTPSProxy", &Network::_GetHTTPSProxy);

    /**
     * @tiapi(method=True,name=Network.getInterfaces,since=0.9)
     * Get a list of interfaces active on this machine.
     * @tiresult[Array<Netowrk.Interface>] An array of active interfaces.
     */
    this->SetMethod("getInterfaces", &Network::_GetInterfaces);

    /**
     * @tiapi(method=True,name=Network.getFirstIPAddress,since=0.9)
     * Get the first IPv4 address in this machine's list of interfaces.
     * @tiarg[String, address] The first IPv4 address in this system's list of interfaces.
     */ 
    this->SetMethod("getFirstIPAddress", &Network::_GetFirstIPAddress);
    this->SetMethod("getAddress", &Network::_GetFirstIPAddress); // COMPATBILITY

    /**
     * @tiapi(method=True,name=Network.getFirstMACAddress,since=0.9)
     * Get the first MAC address in this system's list of interfaces.
     * @tiarg[String, adress] The first MAC address in this system's list of interfaces.
     */
    this->SetMethod("getFirstMACAddress", &Network::_GetFirstMACAddress);
    this->SetMethod("getMACAddress", &Network::_GetFirstMACAddress);

    this->netStatus = new NetworkStatus(this);
    this->netStatus->Start();
}

Network::~Network()
{
    delete this->netStatus;
}

void Network::Shutdown()
{
    listeners.clear();
}

AutoPtr<Host> Network::GetHostBinding(const std::string& hostname)
{
    AutoPtr<Host> binding(new Host(hostname));
    if (binding->IsInvalid())
        throw ValueException::FromString("Could not resolve address");

    return binding;
}

void Network::_GetHostByAddress(const ValueList& args, KValueRef result)
{
    if (args.at(0)->IsObject())
    {
        KObjectRef obj = args.at(0)->ToObject();
        AutoPtr<IPAddress> b = obj.cast<IPAddress>();
        if (!b.isNull())
        {
            // in this case, they've passed us an IPAddressBinding
            // object, which we can just retrieve the ipaddress
            // instance and resolving using it
            Poco::Net::IPAddress addr(b->GetAddress()->toString());
            AutoPtr<Host> binding = new Host(addr);
            if (binding->IsInvalid())
            {
                throw ValueException::FromString("Could not resolve address");
            }
            result->SetObject(binding);
            return;
        }
        else
        {
            KMethodRef toStringMethod = obj->GetMethod("toString");
            if (toStringMethod.isNull())
                throw ValueException::FromString("Unknown object passed");

            result->SetObject(GetHostBinding(toStringMethod->Call()->ToString()));
            return;
        }
    }
    else if (args.at(0)->IsString())
    {
        // in this case, they just passed in a string so resolve as normal
        result->SetObject(GetHostBinding(args.GetString(0)));
    }
}

void Network::_GetHostByName(const ValueList& args, KValueRef result)
{
    result->SetObject(GetHostBinding(args.GetString(0)));
}

void Network::_CreateIPAddress(const ValueList& args, KValueRef result)
{
    AutoPtr<IPAddress> binding = new IPAddress(args.at(0)->ToString());
    if (binding->IsInvalid())
    {
        throw ValueException::FromString("Invalid address");
    }
    result->SetObject(binding);
}

void Network::_CreateTCPSocket(const ValueList& args, KValueRef result)
{
    args.VerifyException("createTCPSocket", "sn");
    std::string host(args.GetString(0));
    int port = args.GetInt(1);
    result->SetObject(new TCPSocket(host, port));
}

void Network::_CreateTCPServerSocket(const ValueList& args, KValueRef result)
{
    args.VerifyException("createTCPServerSocket", "m");
    KMethodRef target = args.at(0)->ToMethod();
    result->SetObject(new TCPServerSocket(target));
}

void Network::_CreateIRCClient(const ValueList& args, KValueRef result)
{
    Logger::Get("Network")->Warn("DEPRECATED: IRCClient will be removed.");
    AutoPtr<IRCClient> irc = new IRCClient();
    result->SetObject(irc);
}

void Network::_CreateHTTPClient(const ValueList& args, KValueRef result)
{
    result->SetObject(new HTTPClient());
}

void Network::_CreateHTTPServer(const ValueList& args, KValueRef result)
{
    result->SetObject(new HTTPServer());
}

void Network::_CreateHTTPCookie(const ValueList& args, KValueRef result)
{
    result->SetObject(new HTTPCookie());
}

void Network::_AddConnectivityListener(const ValueList& args, KValueRef result)
{
    args.VerifyException("addConnectivityListener", "m");
    KMethodRef target = args.at(0)->ToMethod();

    static long nextListenerId = 0;
    Listener listener = Listener();
    listener.id = nextListenerId++;
    listener.callback = target;
    this->listeners.push_back(listener);
    result->SetInt(listener.id);
}

void Network::_RemoveConnectivityListener(
    const ValueList& args, KValueRef result)
{
    args.VerifyException("removeConnectivityListener", "n");
    int id = args.at(0)->ToInt();

    std::vector<Listener>::iterator it = this->listeners.begin();
    while (it != this->listeners.end())
    {
        if ((*it).id == id)
        {
            this->listeners.erase(it);
            result->SetBool(true);
            return;
        }
        it++;
    }
    result->SetBool(false);
}

bool Network::HasNetworkStatusListeners()
{
    return this->listeners.size() > 0;
}

void Network::NetworkStatusChange(bool online)
{
    static Logger* log = Logger::Get("NetworkStatus");
    log->Debug("ti.Network: Online status changed ==> %i", online);
    this->Set("online", Value::NewBool(online));

    ValueList args = ValueList();
    args.push_back(Value::NewBool(online));
    std::vector<Listener>::iterator it = this->listeners.begin();
    while (it != this->listeners.end())
    {
        KMethodRef callback = (*it++).callback;
        try
        {
            RunOnMainThread(callback, args, false);
        }
        catch(ValueException& e)
        {
            SharedString ss = e.GetValue()->DisplayString();
            log->Error("Network.NetworkStatus callback failed: %s", ss->c_str());
        }
    }
}

void Network::_EncodeURIComponent(const ValueList &args, KValueRef result)
{
    if (args.at(0)->IsNull() || args.at(0)->IsUndefined())
    {
        result->SetString("");
    }
    else if (args.at(0)->IsString())
    {
        std::string src = args.at(0)->ToString();
        std::string sResult = URLUtils::EncodeURIComponent(src);
        result->SetString(sResult);
    }
    else if (args.at(0)->IsDouble())
    {
        std::stringstream str;
        str << args.at(0)->ToDouble();
        result->SetString(str.str().c_str());
    }
    else if (args.at(0)->IsBool())
    {
        std::stringstream str;
        str << args.at(0)->ToBool();
        result->SetString(str.str().c_str());
    }
    else if (args.at(0)->IsInt())
    {
        std::stringstream str;
        str << args.at(0)->ToInt();
        result->SetString(str.str().c_str());
    }
    else
    {
        throw ValueException::FromString("Could not encodeURIComponent with type passed");
    }
}

void Network::_DecodeURIComponent(const ValueList &args, KValueRef result)
{
    if (args.at(0)->IsNull() || args.at(0)->IsUndefined())
    {
        result->SetString("");
    }
    else if (args.at(0)->IsString())
    {
        std::string src = args.at(0)->ToString();
        std::string sResult = URLUtils::DecodeURIComponent(src);
        result->SetString(sResult);
    }
    else
    {
        throw ValueException::FromString("Could not decodeURIComponent with type passed");
    }
}

static SharedProxy ArgumentsToProxy(const ValueList& args, const std::string& scheme)
{
    if (args.at(0)->IsNull())
        return 0;

    std::string entry(args.GetString(0));
    if (entry.empty())
        return 0;

    // Do not pass the third argument entryScheme, because it overrides
    // any scheme set in the proxy string.
    return ProxyConfig::ParseProxyEntry(entry, scheme, std::string());
}

void Network::_SetHTTPProxy(const ValueList& args, KValueRef result)
{
    args.VerifyException("setHTTPProxy", "s|0 ?s s s");
    SharedProxy proxy(ArgumentsToProxy(args, "http"));
    ProxyConfig::SetHTTPProxyOverride(proxy);
}

void Network::_GetHTTPProxy(const ValueList& args, KValueRef result)
{
    SharedProxy proxy = ProxyConfig::GetHTTPProxyOverride();

    if (proxy.isNull())
        result->SetNull();
    else
        result->SetString(proxy->ToString().c_str());
}

void Network::_SetHTTPSProxy(const ValueList& args, KValueRef result)
{
    args.VerifyException("setHTTPSProxy", "s|0 ?s s s");
    SharedProxy proxy(ArgumentsToProxy(args, "https"));
    ProxyConfig::SetHTTPSProxyOverride(proxy);
}

void Network::_GetHTTPSProxy(const ValueList& args, KValueRef result)
{
    SharedProxy proxy = ProxyConfig::GetHTTPSProxyOverride();

    if (proxy.isNull())
        result->SetNull();
    else
        result->SetString(proxy->ToString().c_str());
}

void Network::_GetFirstMACAddress(const ValueList& args, KValueRef result)
{
    result->SetString(PlatformUtils::GetFirstMACAddress().c_str());
}

void Network::_GetFirstIPAddress(const ValueList& args, KValueRef result)
{
    static std::string address(Network::GetFirstIPAddress());
    result->SetString(address.c_str());
}

/*static*/
const std::string& Network::GetFirstIPAddress()
{
    return firstIPv4Address;
}

void Network::_GetInterfaces(const ValueList& args, KValueRef result)
{
    result->SetList(interfaceList);
}

} // namespace Titanium
