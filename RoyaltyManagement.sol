// SPDX-License-Identifier: MIT
pragma solidity >= 0.7.0 < 0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RoyaltyNFT is ERC721Enumerable, Ownable {

  using Strings for uint256;

  bool public paused = false;

  uint256 total_volume = 0;

  mapping(address => uint256) private royaltysBalance;

  mapping(address => bool) private registered;

  //mapping(uint256 => string) private SkillIdentifier;


  constructor(  
  ) 
  ERC721("ROYALTY MANAGEMENT", "RMN") { //No need for contructor variables
  }

  // public
   function donate(address developer_wallet) public payable {

    require(!paused, "The contract is paused");
    
    require(developer_wallet == address(developer_wallet),"Invalid address");
    
    require(registered[developer_wallet] == true, "Invalid developer address");
 
    royaltysBalance[developer_wallet] += msg.value;
  
  }


  function isRegistered (address developer_wallet) public view  returns (bool) {

    return registered[developer_wallet];
  
  }

  function checkBalance (address developer_wallet) public view returns (uint256) {
  
    require(registered[developer_wallet] == true, "Invalid developer address/ Not registered!");
  
    return royaltysBalance[developer_wallet];
  
  }

  function withdrawBalance() public payable {
  
    require(registered[msg.sender], "You are not registered as a developer!");
  
    require(royaltysBalance[msg.sender] > 0.01 ether, "Balance is less than 0.01 ether");
  
    (bool success, ) = payable(msg.sender).call{value: royaltysBalance[msg.sender]}("");
  
    require(success);

    total_volume = total_volume + royaltysBalance[msg.sender];

    royaltysBalance[msg.sender] = 0;
  
  }

  //only owner
   function mint(address developer_wallet) public onlyOwner {
    
    require(!paused, "The contract is paused");
    
    require(developer_wallet == address(developer_wallet),"Invalid address");

    //SkillIdentifier[supply + 1] = String_name_input;
    
    uint256 supply = totalSupply();
    
    royaltysBalance[developer_wallet] = 0;
    
    registered[developer_wallet] = true;
    
    _safeMint(developer_wallet, supply + 1);
  }

  function pause(bool _state) public onlyOwner {
    
    paused = _state;
  
  }
  
}
