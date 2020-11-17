::mods_registerMod("mod_recruitBloodline", 1, "Recruit Bloodline");

::mods_hookBaseClass("entity/world/settlement", function ( sub )
{
  while(!("updateRoster" in sub))
    sub = sub[sub.SuperName];

  sub.updateRoster = function( _force = false )
	{
		local daysPassed = (this.Time.getVirtualTimeF() - this.m.LastRosterUpdate) / this.World.getTime().SecondsPerDay;

		if (!_force && this.m.LastRosterUpdate != 0 && daysPassed < 2)
		{
			return;
		}

		if (this.m.RosterSeed != 0)
		{
			this.Math.seedRandom(this.m.RosterSeed);
		}

		this.m.RosterSeed = this.Math.floor(this.Time.getRealTime() + this.Math.rand());
		this.m.LastRosterUpdate = this.Time.getVirtualTimeF();
		local roster = this.World.getRoster(this.getID());
		local current = roster.getAll();
		local iterations = this.Math.max(1, daysPassed / 2);
		local activeLocations = 0;

		foreach( loc in this.m.AttachedLocations )
		{
			if (loc.isActive())
			{
				activeLocations = ++activeLocations;
			}
		}

		local minRosterSizes = [
			0,
			3,
			5,
			7
		];
		local rosterMin = minRosterSizes[this.m.Size] + this.World.Assets.m.RosterSizeAdditionalMin + (this.isSouthern() ? 2 : 0);
		local rosterMax = minRosterSizes[this.m.Size] + activeLocations + this.World.Assets.m.RosterSizeAdditionalMax + (this.isSouthern() ? 1 : 0);

		if (this.World.FactionManager.getFaction(this.m.Factions[0]).getPlayerRelation() < 50)
		{
			rosterMin = rosterMin * (this.World.FactionManager.getFaction(this.m.Factions[0]).getPlayerRelation() / 50.0);
			rosterMax = rosterMax * (this.World.FactionManager.getFaction(this.m.Factions[0]).getPlayerRelation() / 50.0);
		}

		rosterMin = rosterMin * this.m.Modifiers.RecruitsMult;
		rosterMax = rosterMax * this.m.Modifiers.RecruitsMult;

		if (iterations < 7)
		{
			for( local i = 0; i < iterations; i = ++i )
			{
				for( local maxRecruits = this.Math.rand(this.Math.max(0, rosterMax / 2 - 1), rosterMax - 1); current.len() > maxRecruits;  )
				{
					local n = this.Math.rand(0, current.len() - 1);
					roster.remove(current[n]);
					current.remove(n);
				}
			}
		}
		else
		{
			roster.clear();
			current = [];
		}

		local maxRecruits = this.Math.rand(rosterMin, rosterMax);
		local draftList;
		draftList = clone this.m.DraftList;

		foreach( loc in this.m.AttachedLocations )
		{
			loc.onUpdateDraftList(draftList);
		}

		foreach( b in this.m.Buildings )
		{
			if (b != null)
			{
				b.onUpdateDraftList(draftList);
			}
		}

		foreach( s in this.m.Situations )
		{
			s.onUpdateDraftList(draftList);
		}

		this.World.Assets.getOrigin().onUpdateDraftList(draftList);

		while (maxRecruits > current.len())
		{
			local bro = roster.create("scripts/entity/tactical/player");
			bro.setRecruitStartValues(draftList , this.m.CombatSeed);
			current.push(bro);
		}

		this.World.Assets.getOrigin().onUpdateHiringRoster(roster);
	};

});

::mods_hookBaseClass("entity/tactical/human", function ( sub )
{
  sub.fillRecruitTalents <- function(_seed)
  {
		this.m.Talents.resize(this.Const.Attributes.COUNT, 0);

		if (this.getBackground() != null && this.getBackground().isUntalented())
		{
			return;
		}

    local seed = this.Math.rand();

    this.Math.seedRandomString(_seed + this.m.Background.m.Name);
		for( local done = 0; done < 3;  )
		{
			local i = this.Math.rand(0, this.Const.Attributes.COUNT - 1);

			if (this.m.Talents[i] == 0 && (this.getBackground() == null || this.getBackground().getExcludedTalents().find(i) == null))
			{
        this.m.Talents[i] = 1;
				done = ++done;
			}
		}

    this.Math.seedRandom(this.Time.getRealTime() + seed);
    for(local a = 0 ; a < this.m.Talents.len() ; a = a+1)
		{
			if (1 == this.m.Talents[a])
      {
				local r = this.Math.rand(1, 100);

				if (r <= 60)
				{
					this.m.Talents[a] = 1;
				}
				else if (r <= 90)
				{
					this.m.Talents[a] = 2;
				}
				else
				{
					this.m.Talents[a] = 3;
				}
			}
		}
/*
    local log = this.m.Name + " " + this.m.Background.m.Name;
    for(local a = 0 ; a < this.m.Talents.len() ; a = a+1)
    {
      if(this.m.Talents[a] > 0)
        log = log + " " + a + "-" + this.m.Talents[a];
    }
    this.logInfo(log);
*/
  };

  sub.setRecruitStartValues <- function( _backgrounds, _seed)
	{
		if (this.isSomethingToSee() && this.World.getTime().Days >= 7)
		{
			_backgrounds = this.Const.CharacterPiracyBackgrounds;
		}

		local background = this.new("scripts/skills/backgrounds/" + _backgrounds[this.Math.rand(0, _backgrounds.len() - 1)]);
		this.m.Skills.add(background);
		this.m.Background = background;
		this.m.Ethnicity = this.m.Background.getEthnicity();
		background.buildAttributes();
		background.buildDescription();

		if (this.m.Name.len() == 0)
		{
			this.m.Name = background.m.Names[this.Math.rand(0, background.m.Names.len() - 1)];
		}

		//add traits
		{
			local maxTraits = this.Math.rand(this.Math.rand(0, 1) == 0 ? 0 : 1, 2);
			local traits = [
				background
			];

			for( local i = 0; i < maxTraits; i = ++i )
			{
				for( local j = 0; j < 10; j = ++j )
				{
					local trait = this.Const.CharacterTraits[this.Math.rand(0, this.Const.CharacterTraits.len() - 1)];
					local nextTrait = false;

					for( local k = 0; k < traits.len(); k = ++k )
					{
						if (traits[k].getID() == trait[0] || traits[k].isExcluded(trait[0]))
						{
							nextTrait = true;
							break;
						}
					}

					if (!nextTrait)
					{
						traits.push(this.new(trait[1]));
						break;
					}
				}
			}

			for( local i = 1; i < traits.len(); i = ++i )
			{
				this.m.Skills.add(traits[i]);

				if (traits[i].getContainer() != null)
				{
					traits[i].addTitle();
				}
			}
		}

		background.addEquipment();
		background.setAppearance();
		background.buildDescription(true);
		this.m.Skills.update();
		local p = this.m.CurrentProperties;
		this.m.Hitpoints = p.Hitpoints;

    this.fillRecruitTalents(_seed);
    this.fillAttributeLevelUpValues(this.Const.XP.MaxLevelWithPerkpoints - 1);
	}
});