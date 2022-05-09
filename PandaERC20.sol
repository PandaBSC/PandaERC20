//SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.8.0;


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract pandaERC20 is Initializable, ERC20Upgradeable {
    /*
    本合约发行Panda币，最大供应量10亿枚，初始发行量1亿枚。
    */
    bool private initialized;
    address private admin;
    address private maxSupply;
    uint private maintain;
    uint leftSupply;
    mapping (address => uint) private controller;

    function initialize() public initializer {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        __ERC20_init("Panda","Panda");
        admin = msg.sender;
        leftSupply = 900000000000000000000000000;
        _mint(msg.sender,100000000000000000000000000);
        }

    fallback() external payable{}
    receive() external payable{}


    ////////////////////////////////////////////////////////////////
    //modifier here.

    //admin only
    modifier onlyAdmin {
        require(msg.sender == admin, "admin only");
        _;
    }

    //not in maintain
    modifier notMaintain {
        require(maintain == 0, "In maintainance");
        _;
    }
    //modifier uphere.
    ////////////////////////////////////////////////////////////////

    event burnEvent(address _from, uint _value);
    event mintEvent(address _controller, address _to, uint _value);

    function burn(address _from, uint _value) public notMaintain returns (bool) {
        _burn(_from, _value);
        emit burnEvent(_from, _value);
        return true;
    }

    function mint(address _to, uint _value) notMaintain public returns (bool) {
        require(leftSupply >= _value, "leftSupply is not enough");
        require(controller[msg.sender] >= _value, "controller's value is not enough");
        controller[msg.sender] -= _value;
        _mint(_to, _value);
        leftSupply -= _value;
        emit mintEvent(msg.sender, _to, _value);
        return true;
    }

    function getLimit(address _controller) public view returns (uint) {
        return controller[_controller];
    }

    ///////////////////////////////////////////////////////////////
    //admin functions here

    //add/delete the controller
    function setController(address _controlAddress, uint _value) onlyAdmin public {
        controller[_controlAddress] = _value;
    }

    function setAdmin(address _adminAddress) onlyAdmin public {
        admin = _adminAddress;
    }

    function addSupply(uint _addSupply) onlyAdmin public returns (uint) {
        leftSupply += _addSupply;
        return leftSupply;
    }

    function getLeftSupply() public view returns (uint) {
        return leftSupply;
    }

    function getBalance(address _token) public view returns (uint) {
        IERC20 token = IERC20(_token);
        return token.balanceOf(address(this));
    }

    function withDraw(address _token, uint _value) onlyAdmin public returns (bool) {
        IERC20 token = IERC20(_token);
        require(token.balanceOf(address(this)) >= _value);
        token.transfer(msg.sender,_value);
        return true;
    }
    
    function withDrawBNB() onlyAdmin public {
        payable(msg.sender).transfer(address(this).balance);
    }



    function setMaintain(uint _state) onlyAdmin public {
        maintain = _state;
    }
}
