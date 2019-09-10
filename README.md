# PoorsManNICFailover

   En Windows 10 no hi ha teaming. Intel té un driver que teòricament ho resol, però després
    de moltes proves, no hem aconseguit fer-ho funcionar de forma estable. Com que hem de posar
    les màquines en producció, aquest script de merda permet fer una xapussa per sortir del pas.

    Bàsicament la idea és tenir una tasca programada que executa aquest script que verifica si la 
    tarja activa té link, i en cas de que no en tingui, l'script
    - Desactiva el NIC
    - El desconfigura
    - Activa la segona tarja
    - La configura


CREDITS

Utilitza Logging_Functions.ps1 
    https://gist.github.com/9to5IT/9620565
    Version:        1.1
    Author:         Luca Sturlese
    Creation Date:  19/05/12