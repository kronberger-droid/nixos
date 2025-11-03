{ pkgs, ... }:
{
  home.packages = with pkgs; [
    dprint
  ];

  home.file.".dprint.json".text = ''
    		{
    			"lineWidth": 120,
    			"indentWidth": 2,
    			"plugins": [
    				{
    					"name": "markdown",
    					"path": "${pkgs.dprint-plugins.dprint-plugin-markdown}"
    				}
    			]
    		}
    	'';
}

