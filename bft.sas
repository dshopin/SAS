/*This is a code for analysis of combinations of two key variables and determining if some combinations have*/
/*one-to-one relation (so the first key value occurs only in combination with the second value, and neither of*/
/*them both occur anywhere else), and some have one-to-many or many-to-many relations.*/
/*Basically it's a problem of finding connected components of a graph*/
/*where vertices are key values of the 1st or the 2nd type, and edges - relation between two key values of  different */
/*types.*/
/*The code below utilizes Breadth-First Tree search algorithm.*/


/*Creating test dataset (adjacency matrix - all distinct combinations of names and IDs)*/
data edges;
	infile datalines dsd dlm=',';
	input name $ id $ @@;
datalines;
Adam,1,Berta,2,Chris,3,David,3,David,4,John,4,Elena,5,Elena,1,Fred,6,Ken,3,Ken,7,Chris,7,Liam, ,Mary, , ,8, ,9
;
run;

/*BFT-search*/
data _null_;

	if _N_=1 then do;
		/*Hash for the list of distinct vertices (both types in one column)*/
		/*variable 'color' is for denoting unprocessed vertices as 'white' and processed ones as 'black'*/
		/*variable 'type' will show if this value is name or ID*/
		/*variable 'group' will denote a certain connected component which includes the current pair name-ID*/
		declare hash G();
		declare hiter GIter('G');
		G.defineKey('vert','type');
		G.defineData('vert','type','color', 'group');
		G.defineDone();

		/*Hash for the adjacency list for looking up by names*/
		declare hash An(multidata:'y');
		An.defineKey('vert');
		An.defineData('vert','child');
		An.defineDone();

		/*Hash for the adjacency list for looking up by id*/
		declare hash Ai(multidata:'y');
		Ai.defineKey('vert');
		Ai.defineData('vert','child');
		Ai.defineDone();

		/*Has for the queue. 'Num' - for ordering vertices in queue in the order of enqueueing
		to realize mechanism FIFO*/
		declare hash Q(ordered:'a');
		declare hiter QIter('Q');
		Q.defineKey('num','vert');
		Q.defineData('num','vert','type');
		Q.defineDone();
	end;

	/*Loading data into Vertices List and Adjacency List*/
	do  until(eof);
		length vert child $50;
		set edges end=eof;
		color='w';
		group=.;
		if not missing(name) then do;
			vert=name;
			type='name';
			child=id;
			G.ref();
			/*we add edge only with both non-missing vertices. So that each pair Name1-. will be
			a separate group, not mixing with others (Name2-., .-ID1*/
			if not missing(id) then An.add();
		end;
		if not missing(id) then do;
			vert=id;
			type='id';
			child=name;
			G.ref();
			if not missing(name) then Ai.add();
		end;
	end;
	/*Counter for 'groups' or connected components*/
	n=0;

	/*Counter for ordering elements in the queue*/
	num=0;

	/*This loop enqueues graph's vertices (name or ID),
	i.e. takes every vertice one-by-one, skipping those that were already enqueued during
	breadth-first analysis of previous connected components*/
	rc1=GIter.first();
	do 	
/*i=1 to 2;*/
while(rc1=0);
		if color='w' then do;

			/*Enqueque element from G*/
			num=num+1;
			n=n+1;
			Q.add();
			G.replace(key:vert,key:type,data:vert,data:type,data:'b',data:n);

			/*Dequeue first element in the queue*/
			rc2=QIter.first();
			do 	while(rc2=0);
				
				/*if this element is name then*/
				if type='name' then do;
					/*look up by name for all adjacent vertices (children) - IDs*/
					rc3=An.find();
					do while(rc3=0);
							vert=child;
							type='id';
							/*checking child in Vertices List*/
							G.find();
							/*If it's still 'white', then add to the queue and change color to 'black'*/
							if color='w' then do;
								num=num+1;
								Q.add();
								G.replace(key:vert,key:type,data:vert,data:type,data:'b',data:n);
							end;
							rc3=An.find_next();
					end;
				end;

				/*if this element is ID then*/
				else if type='id' then do;
					/*look up by ID for all adjacent vertices (children) - names*/
					rc4=Ai.find();
					do while(rc4=0);
							vert=child;
							type='name';
							/*checking child in Vertices List*/
							rc=G.find();
							/*If it's still 'white', then add to the queue and change color to 'black'*/
							if color='w' then do;
								num=num+1;
								Q.add();
								G.replace(key:vert,key:type,data:vert,data:type,data:'b',data:n);
							end;
							rc4=Ai.find_next();
					end;
				end;
				/*To delete first element in the queue we must delete hash iterator*/
				QIter.first();
				QIter.delete();
				Q.remove();
				/*Now we can re-create hash iterator*/
				QIter=_new_ hiter ('Q')	;
				rc2=QIter.first();
			end;
		end;
		rc1=GIter.next();
	end;
	G.output(dataset:'result');
run;

proc sql;
	create table groups as
	select e.name, e.id, r.group
	from edges e left join result r
	on (
		not missing(e.name)
		and e.name=r.vert
		)
		or
		(
		missing(e.name)
		and e.id=r.vert
		)
	order by r.group;
quit;
