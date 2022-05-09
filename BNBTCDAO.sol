//SPDX-License-Identifier:SimPL-2.0
pragma solidity ^0.8.0;


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract BNBTCDAO is Initializable {

    struct Vote {
        uint id;
        IERC20 token;
        uint startBlock;
        uint endBlock;
        uint8 optionNumber;
        mapping (uint8 => uint) option;
        mapping (address => uint8) voter;
        address[] voterList;
    }

    address admin;
    bool private initialized;

    mapping (uint => Vote) proposals;

    function initialize() public initializer {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        admin = msg.sender;
    }

    fallback() external payable{}
    receive() external payable{}


    modifier onlyAdmin {
        require(admin == msg.sender, "you are not the admin");
        _;
    }

    modifier activeProposal(uint _proposal) {
        require(block.number >= proposals[_proposal].startBlock && block.number <= proposals[_proposal].endBlock, "the proposal is not active");
        _;
    }

    //user can vote by sending the transaction, the proposal number and option to vote needed.
    function putVote(uint _proposal, uint8 _option) public activeProposal(_proposal) {
        Vote storage p = proposals[_proposal];
    	require(p.token.balanceOf(msg.sender) > 0, "token holder only");
        if (p.voter[msg.sender] == 0) {
            p.voterList.push(msg.sender);
        }
        p.voter[msg.sender] = _option;
        _calculateProposal(_proposal);
    }

    //for a proposal, this function can get the vote amount for every options
    function getVote(uint _proposal, uint8 _option) public view returns (uint) {
        return  proposals[_proposal].option[_option];
    }

    //for a proposal, this function can get the vote amount for every options
    function getProposal(uint _proposal) public view returns (uint, uint) {
        return  (proposals[_proposal].startBlock, proposals[_proposal].endBlock);
    }


    //get the voter's vote option, if 0 means no vote yet.
    function getvoter(uint _proposal, address _account) public view returns (uint8) {
        return proposals[_proposal].voter[_account];
    }

    function _calculateProposal(uint _proposal) private {
        Vote storage p = proposals[_proposal];
        uint[] memory _votes = new uint[](p.optionNumber+1);
        for (uint i=0; i < p.voterList.length; i++) {
            address _voter = p.voterList[i];
            _votes[p.voter[_voter]] += p.token.balanceOf(_voter);
        }
        for (uint8 i=0; i < p.optionNumber; i++) {
            p.option[i+1] = _votes[i+1];    
        }
    }


    //this function allow the admin to create a proposal and config the start and end;
    function setProposal(uint _proposalId, IERC20 _token, uint8 _optionNumber, uint _startBlock, uint _endBlock) public onlyAdmin {
        proposals[_proposalId].id = _proposalId;
        proposals[_proposalId].token = _token;
        proposals[_proposalId].optionNumber = _optionNumber;
        proposals[_proposalId].startBlock = _startBlock;
        proposals[_proposalId].endBlock = _endBlock;
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


}