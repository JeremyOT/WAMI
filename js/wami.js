var WAMI = WAMI || {};
(function(wami) {
  var registeredAppMethods = {},
      activeMethodFutures = {},
      platformChangedHandler = null,
      Future = (function() {

        var FutureInitialized = 0, FutureFinished = 1, FutureFailed = 2, FutureReverted = 3;

        function Future() {
          this._state = FutureInitialized;
          this._onError = [];
          this._onFinish = [];
          this._onRevert = [];
          this._result = null;
        };

        Future.prototype.finish = function() {
          this._result = arguments;
          this._state = FutureFinished;
          for(var i = 0; i < this._onFinish.length; i++) {
            this._onFinish[i].apply(null, this._result);
          }
        };

        Future.prototype.fail = function() {
          this._result = arguments;
          this._state = FutureFailed;
          for(var i = 0; i < this._onError.length; i++) {
            this._onError[i].apply(null, this._result);
          }
        };

        Future.prototype.revert = function() {
          this._result = arguments;
          this._state = FutureReverted;
          for(var i = 0; i < this._onRevert.length; i++) {
            this._onRevert[i].apply(null, this._result);
          }
        };

        Future.prototype.then = function(handler) {
          this._onFinish.push(handler);
          if(this._state == FutureFinished) {
            handler.apply(null, this._result);
          }
          return this;
        };

        Future.prototype.error = function(handler) {
          this._onError.push(handler);
          if(this._state == FutureFailed) {
            handler.apply(null, this._result);
          }
          return this;
        };

        Future.prototype.fallback = function(handler) {
          this._onRevert.push(handler);
          if(this._state == FutureReverted) {
            handler.apply(null, this._result);
          }
          return this;
        };

        return Future;
      })();
      

  function setCurrentPlatform(platform, standardConsole) {
    wami.platform = platform;
    if (wami.platform && !standardConsole) {
      wami.overrideConsole();
    }
    switch (wami.platform) {
      case 'iOS':
        wami.invokeMethod = function(method, callID, args, expectsResponse) {
          window.location.href = 'wami://' + JSON.stringify({'method': method, 'parameters': args, 'callID': callID, 'expectsResponse': expectsResponse});
        }
        break;
      case 'Android':
        wami.invokeMethod = function(method, callID, args, expectsResponse) {
          WAMIAndroidBridge.invoke(method, callID, JSON.stringify(args), expectsResponse);
        }
        break;
      default:
        delete wami.invokeMethod; 
    }
    wami.platformChanged();
  }

  function platformChanged(handler) {
    if (handler) {
      platformChangedHandler = handler;
    } else if (wami.platformChangedHandler) {
      platformChangedHandler(wami.platform);
    }
  }

  function appMethod(method) {
    var args = Array.prototype.slice.call(arguments, 1),
        registeredMethod = registeredAppMethods[method],
        future = new Future();
    if (!registeredMethod) {
      throw 'error: method "' + method + '" not registered';
    }
    if (registeredAppMethods[method].fallbackFunction) {
      future.fallback(function() {
        args.splice(0, 0, future);
        registeredAppMethods[method].fallbackFunction.apply(null, args);
      });
    }
    if (wami.platform) {
      callID = Math.floor(Math.random() * 0x10000000).toString(16)
      if (registeredMethod.expectsResponse) activeMethodFutures[callID] = future;
      wami.invokeMethod(method, callID, args, registeredMethod.expectsResponse);
    } else {
      future.revert();
    }
    return future;
  }

  function registerAppMethod(method, fallbackFunction, expectsResponse) {
    registeredAppMethods[method] = {'fallbackFunction': fallbackFunction, 'expectsResponse': !!expectsResponse};
  }

  function finishAppMethod(callID) {
    var future = activeMethodFutures[callID]
    delete activeMethodFutures[callID]
    future.finish.apply(future, Array.prototype.slice.call(arguments, 1))
  }

  function failAppMethod(callID) {
    var future = activeMethodFutures[callID]
    delete activeMethodFutures[callID]
    future.fail.apply(future, Array.prototype.slice.call(arguments, 1))
  }

  function revertAppMethod(method, callID, parameters) {
    var future = activeMethodFutures[callID]
    delete activeMethodFutures[callID]
    if (future) {
      future.revert.apply(future);
    } else {
      parameters.splice(0, 0, null);
      registeredAppMethods[method].fallbackFunction.apply(null, parameters);
    }
  }

  function overrideConsole() {
    wami.nativeConsole = console;
    wami.registerAppMethod('console', function(future, parameters) {
      var logType = parameters[0],
          args = Array.prototype.slice.call(arguments, 1);
      wami.nativeConsole[logType].apply(wami.nativeConsole, args);
    });
    function logFunction(logType) {
      return function() {
        var args = Array.prototype.splice.call(arguments, 0);
        args.splice(0, 0, 'console', logType);
        wami.appMethod.apply(wami, args);
      };
    };
    window.console = {
      log: logFunction('log'),
      info: logFunction('info'),
      debug: logFunction('debug'),
      warn: logFunction('warn'),
      error: logFunction('error')
    };
    var onerror = window.onerror;
    window.onerror = function(error, url, linenumber) {
      console.error({'error': error, 'url': url, 'lineNumber': linenumber});
      if (onerror) {
        return onerror;
      }
      return false;
    }
  }

  wami.appMethod = appMethod;
  wami.setCurrentPlatform = setCurrentPlatform;
  wami.registerAppMethod = registerAppMethod;
  wami.finishAppMethod = finishAppMethod;
  wami.failAppMethod = failAppMethod;
  wami.revertAppMethod = revertAppMethod;
  wami.Future = Future;
  wami.overrideConsole = overrideConsole;
  wami.platformChanged = platformChanged;

  if (window.WAMIAndroidBridge) {
    WAMIAndroidBridge.register();
  }
})(WAMI);
