// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;

import "./lib/upgrades/Initializable.sol";
import "./lib/upgrades/AdminUpgradeabilityProxy.sol";
import {IInstrumentStorage} from "./interfaces/InstrumentInterface.sol";
import {IChiToken} from "./interfaces/IChiToken.sol";
import {Ownable} from "./lib/Ownable.sol";

contract RibbonFactoryStorageV1 is Ownable {
    /**
     * @notice Address of the admin of all instruments
     */
    address public instrumentAdmin;

    /**
     * @notice Mapping of created instruments
     */
    mapping(string => address) public instruments;

    /**
     * @notice Boolean check for if an address is an instrument
     */
    mapping(address => bool) public isInstrument;

    mapping(string => address) public getAdapter;

    address[] public adapters;
}

contract RibbonFactory is Initializable, RibbonFactoryStorageV1 {
    address constant CHI_GAS_TOKEN = 0x0000000000004946c0e9F43F4Dee607b0eF1fA1c;
    uint256 constant GAS_TOKEN_SUBSIDY = 30;

    /**
     * @notice Emitted when a new instrument is created
     */
    event InstrumentCreated(string symbol, address indexed instrumentAddress);

    /**
     * @notice Emitted when a new instrument is created
     */
    event ProxyCreated(
        address indexed logic,
        address indexed proxyAddress,
        bytes initData
    );

    event AdapterSet(
        string indexed protocolName,
        address indexed adapterAddress
    );

    /**
     * @notice Constructor takes a DataProvider contract address
     */
    function initialize(address _owner, address _instrumentAdmin)
        public
        initializer
    {
        Ownable.initialize(_owner);
        instrumentAdmin = _instrumentAdmin;
    }

    /**
     * @notice Getter for getting contract address by instrument name
     */
    function getInstrument(string memory _name)
        public
        view
        returns (address instrumentAddress)
    {
        instrumentAddress = instruments[_name];
    }

    function newInstrument(address _logic, bytes memory _initData)
        public
        onlyOwner
        returns (address instrumentAddress)
    {
        instrumentAddress = createProxy(_logic, _initData);
        IInstrumentStorage instrument = IInstrumentStorage(instrumentAddress);
        string memory symbol = instrument.symbol();
        require(instruments[symbol] == address(0), "Instrument already exists");

        instruments[symbol] = instrumentAddress;
        isInstrument[instrumentAddress] = true;
        emit InstrumentCreated(symbol, instrumentAddress);
    }

    function createProxy(address _logic, bytes memory _initData)
        private
        returns (address)
    {
        AdminUpgradeabilityProxy proxy =
            new AdminUpgradeabilityProxy(_logic, instrumentAdmin, _initData);
        emit ProxyCreated(_logic, address(proxy), _initData);
        return address(proxy);
    }

    function burnGasTokens() public {
        require(isInstrument[msg.sender], "Caller is not instrument");
        IChiToken chiToken = IChiToken(CHI_GAS_TOKEN);
        chiToken.freeUpTo(GAS_TOKEN_SUBSIDY);
    }

    function setAdapter(string memory protocolName, address adapter)
        public
        onlyOwner
    {
        getAdapter[protocolName] = adapter;
        adapters.push(adapter);
        emit AdapterSet(protocolName, adapter);
    }

    function getAdapters() external view returns (address[] memory _adapters) {
        return adapters;
    }
}
