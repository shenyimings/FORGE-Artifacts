// SPDX-License-Identifier: GPL-3.0

/*//////////////////////////////////////////////////////////////////////////////////////////////////
*
*   _____ ____  __  __ __  __          _   _ _____  ______ _____    _____  ______ ______ _____ 
*  / ____/ __ \|  \/  |  \/  |   /\   | \ | |  __ \|  ____|  __ \  |  __ \|  ____|  ____|_   _|
* | |   | |  | | \  / | \  / |  /  \  |  \| | |  | | |__  | |__) | | |  | | |__  | |__    | |  
* | |   | |  | | |\/| | |\/| | / /\ \ | . ` | |  | |  __| |  _  /  | |  | |  __| |  __|   | |  
* | |___| |__| | |  | | |  | |/ ____ \| |\  | |__| | |____| | \ \  | |__| | |____| |     _| |_ 
*  \_____\____/|_|  |_|_|  |_/_/    \_\_| \_|_____/|______|_|  \_\ |_____/|______|_|    |_____|
*                                                                                              
*                                                                                            
*//////////////////////////////////////////////////////////////////////////////////////////////////

pragma solidity ^0.8.3;

contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}