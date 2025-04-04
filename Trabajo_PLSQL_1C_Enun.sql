
/*
 * PRACTICA 2 APLICACIÓN DE BASES DE DATOS. PLSQL
 *
 * REPO DE GITHUB:
 *      https://github.com/Dankof04/Practica2_PL-SQL.git
 *
 * AUTORES:
 *      Aaron del Santo Izquierdo
 *      Daniel Miguel Muiña
 *      Nicolás Villanueva Ortega
 */

DROP TABLE detalle_pedido CASCADE CONSTRAINTS;
DROP TABLE pedidos CASCADE CONSTRAINTS;
DROP TABLE platos CASCADE CONSTRAINTS;
DROP TABLE personal_servicio CASCADE CONSTRAINTS;
DROP TABLE clientes CASCADE CONSTRAINTS;

DROP SEQUENCE seq_pedidos;


-- Creación de tablas y secuencias

create sequence seq_pedidos;

CREATE TABLE clientes (
    id_cliente INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    telefono VARCHAR2(20)
);

CREATE TABLE personal_servicio (
    id_personal INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    pedidos_activos INTEGER DEFAULT 0 CHECK (pedidos_activos <= 5)  -- P4.1
);

CREATE TABLE platos (
    id_plato INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    disponible INTEGER DEFAULT 1 CHECK (DISPONIBLE in (0,1))
);

CREATE TABLE pedidos (
    id_pedido INTEGER PRIMARY KEY,
    id_cliente INTEGER REFERENCES clientes(id_cliente),
    id_personal INTEGER REFERENCES personal_servicio(id_personal),
    fecha_pedido DATE DEFAULT SYSDATE,
    total DECIMAL(10, 2) DEFAULT 0
);

CREATE TABLE detalle_pedido (
    id_pedido INTEGER REFERENCES pedidos(id_pedido),
    id_plato INTEGER REFERENCES platos(id_plato),
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (id_pedido, id_plato)
);


	
-- Procedimiento a implementar para realizar la reserva
create or replace procedure registrar_pedido(
    arg_id_cliente      INTEGER, 
    arg_id_personal     INTEGER, 
    arg_id_primer_plato INTEGER DEFAULT NULL,
    arg_id_segundo_plato INTEGER DEFAULT NULL
) is 

    -- DECLARACIÓN DE EXCEPCIONES
    plato_no_disponible EXCEPTION;
    PRAGMA EXCEPTION_INIT(plato_no_disponible, -20001);
    pedido_sin_plato EXCEPTION;
    PRAGMA EXCEPTION_INIT(pedido_sin_plato, -20002);
    personal_sin_hueco_disponible EXCEPTION;
    PRAGMA EXCEPTION_INIT(personal_sin_hueco_disponible, -20003);
    plato_inexistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(plato_inexistente, -20004);
    
    --DECLARACIÓN DEL CURSOR
    CURSOR c_plato (v_id_plato INTEGER) IS
        SELECT precio,disponible
        FROM platos
        WHERE id_plato = v_id_plato;
    
    --DECLARACIÓN DE VARIABLES
    v_precioPlato DECIMAL(10, 2);
    v_disponibilidad INTEGER;
    v_precioTotal DECIMAL(10, 2);
    v_cantidadPlato INTEGER;
    v_numPedidos INTEGER;
    

 begin
    --Inicializo la variable del precio total del pedido y la cantidad de cada plato
    v_precioTotal:=0;
    v_cantidadPlato:=1;
    
    --Comprobación de que el pedido contiene algún plato
    IF arg_id_primer_plato IS NULL AND arg_id_segundo_plato IS NULL
    THEN
        raise_application_error(-20002, 'El pedido debe contener al menos un plato');
    END IF;
    
    --Realizo las comprobaciones para el primer plato
    IF arg_id_primer_plato IS NOT NULL
    THEN
        OPEN c_plato(arg_id_primer_plato);
        FETCH c_plato INTO v_precioPlato,v_disponibilidad;
        IF c_plato%NOTFOUND THEN
            raise_application_error(-20004, 'El primer plato seleccionado no existe');
        ELSIF v_disponibilidad = 0 THEN
            raise_application_error(-20001, 'Uno de los platos seleccionados no esta disponible');
        END IF;
        v_precioTotal:=v_precioTotal+v_precioPlato;
        CLOSE c_plato;
    END IF;
    
    --Si el primer plato es correcto y los dos ids son iguales(mismo plato)
    --Modifico solo dos variables y me ahorro mas comprobación de excepciones
    IF arg_id_primer_plato = arg_id_segundo_plato THEN
        v_precioTotal:=v_precioTotal+v_precioPlato;
        v_cantidadPlato:=2;
        
    --Sino realizo las comprobaciones para el segundo plato
    ELSIF arg_id_segundo_plato IS NOT NULL
    THEN
        OPEN c_plato(arg_id_segundo_plato);
        FETCH c_plato INTO v_precioPlato,v_disponibilidad;
        IF c_plato%NOTFOUND THEN
            raise_application_error(-20004, 'El segundo plato seleccionado no existe');
        ELSIF v_disponibilidad = 0 THEN
            raise_application_error(-20001, 'Uno de los platos seleccionados no esta disponible');
        END IF;
        v_precioTotal:=v_precioTotal+v_precioPlato;
        CLOSE c_plato;
    END IF;
        
        
    --Si hemos llegado aquí es que los platos existen y están disponibles.    
    --En esta parte actualizo los pedidos del personal, lo bloqueo para escritura
    --Gracias al bloqueo evito que otra transacción modifique el dato hasta que yo finalice
    SELECT pedidos_activos INTO v_numPedidos FROM personal_servicio
    WHERE personal_servicio.id_personal=arg_id_personal FOR UPDATE; -- P4.2
    
    --Si en esta parte viola la constraint saltara excepcion y la capturo en su bloque
    --Esta es la ultima excepción que podría saltar en el proceso
    UPDATE personal_servicio
    SET pedidos_activos = v_numPedidos + 1
    WHERE personal_servicio.id_personal=arg_id_personal; --P4.3
    
    --Inserto el pedido en la tabla de pedidos
    INSERT INTO pedidos (id_pedido, id_cliente, id_personal,total)
    VALUES (seq_pedidos.nextval, arg_id_cliente, arg_id_personal, v_precioTotal);
    
    --Inserto los detallles del pedido en la tabla correspondiente
    --Si el valor de cantidadPlato es 2, significa que se han introducido
    --dos platos iguales, por lo tanto hacemos una sola inserción
    IF v_cantidadPlato=2 THEN
        INSERT INTO detalle_pedido (id_pedido, id_plato, cantidad)
        VALUES (seq_pedidos.currval,arg_id_primer_plato,2);
    -- Si no, significa que por lo menos realizaremos una insercion de un
    --solo plato, pero pueden ser dos.
    ELSE
    --Aquí se inserta cada plato, ya que si este no es null y se ha llegado
    --hasta este punto, esque existe y está disponible.
        IF arg_id_primer_plato IS NOT NULL
        THEN
            INSERT INTO detalle_pedido (id_pedido, id_plato, cantidad)
            VALUES (seq_pedidos.currval,arg_id_primer_plato,1);
        END IF;
        
        IF arg_id_segundo_plato IS NOT NULL
        THEN
            INSERT INTO detalle_pedido (id_pedido, id_plato, cantidad)
            VALUES (seq_pedidos.currval,arg_id_segundo_plato,1);
        END IF;
    END IF;
    --Comiteamos al final del procedimiento (atomicidad) si ha llegado
    --hasta este punto.
    commit;
    
    --Capturamos la excepción que salta si violamos el check de la tabla
    --de personal-servicio y lo transformamos en la excepción que queremos
    --Cualquier otra excepción se propaga
    --En cualquier caso haríamos un rollback ya que ha habido un error
 exception   
    when others then
        IF SQLCODE=-2290 THEN
            rollback;
            raise_application_error(-20003, 'El personal de servicio tiene demasiados pedidos');
        ELSE
            rollback;
            raise;
        END IF;
            
end;
/

  /*
   * RESPUESTAS A LAS CUESTIONES PLANTEADAS
   * Las referencias a las preguntas se encuentran señaladas en el código, somo se solicita en el enunciado.
   * La P4.1 se encuentra en el check de la tabla, P4.2 en el FOR UPDATE y por último la P4.3 en la actualización
   * de la tabla personal_servicio, que es el lugar donde podría saltar la última de las excepciones.
   *
   * P4.1 -----------------------------------------------------------------------------------------------------
   * Contamos con un check en el cual comprobamos que el valor de pedidos activos para cada miembro del personal
   * sea siempre menor o igual que 5. Si se viola esta condición, se lanza automaticamente una excepción.
   * Además, contamos con un test específico en el cuál verificamos el comportamiento del código para un caso en
   * el que un trabajador con ya 5 pedidos activos. Trata de incluir un sexto pedido a un miembro del personal, 
   * resultando en la correcta ejecución del test si no se produjera la inserción. Avisará lanzando una excepción 
   * con el código -20003 y un mensaje informativo.
   *
   *
   * P4.2 -----------------------------------------------------------------------------------------------------
   * Una vez se verifica que los platos existen y están disponibles, se selecciona el campo personal_pedidos
   * bloqueandolo para escritura (FOR UPDATE). De esta forma, si otra transacción concurrente intenta realizar
   * el procedimiento de reserva, se verá obligada a modificar dicho campo. Como esta bloqueado tendrá que 
   * esperar a que la primera termine. A su vez la primera para poder hacer la comprobacion de pedidos maximos 
   * del trabajador gracias al check que posee dicho campo sin interferencias con otras transacciones.
   *
   *
   * P4.3 -----------------------------------------------------------------------------------------------------
   * Podemos asegurar que un pedido se completará de manera correcta incluso en entornos concurrentes debido al
   * uso del FOR UPDATE, que bloquea el campo personal_pedidos para escritura, garantizando así la secuencialidad 
   * de las transacciones. De esta forma si otra transacción intenta asignar al miembro del personal otro pedido, 
   * deberá esperar antes de completar dicha asignación hasta que la primera haya terminado.
   * Además al llegar a ese punto, ya se habrán realizado todas las comprobaciones de los platos. Como sabemos que
   * los platos son correctos, ya se ha hecho la comprobación del núemero de pedidos para el empleado y tenemos
   * dicho campo bloqueado para escritura, la transacción finalizará sin ningún problema.
   *
   *
   * P4.4 -----------------------------------------------------------------------------------------------------
   * El hipotético check por el que se nos pregunta, ya estaba incluido en la correspondiente tabla a la hora de 
   * descargarnos este fichero. Por ello lo hemos empleado para la resolución de nuestro procedimiento.
   *
   * Al tener puesto un check de pedidos <= 5, si en algun momento se viola este check saltará la excepcion con
   * error -02290, que luego nosotros capturamos en el bloque de excepciones y relanzamos con el codigo -20003. 
   * En caso de que salte la excepcion al al capturarse en el bloque de excepciones se realizará un rollback y 
   * se propagará. 
   *
   * Gracias al rollback no se guardarán modificaciones incorrectas o incompletas y la base quedará 
   * en un estado consistente. La excepción nos permitirá saber cual ha sido el error que se produjo durante la 
   * realización del pedido. El hecho de haber bloqueado el campo para escritura al hacer la select, permite que 
   * no haya incongruencias entre diversos usuarios a la hora de la realización del check.
   *
   *
   * P4.5 -------------------------------------------------------------------------------------------------------
   * Se ha empleado una estrategia de programación estructurada y modular. Se han incluido mecanismos de control 
   * de errores (empleando el tratamiento de excepciones) y de la transaccionalidad.
   *
   * Empleamos programación estructurada ya que el ćodigo se organiza en bloques lógicos (validamos las entradas,
   * comprobamos existencia y disponibilidad, actualización e inserción) y permite una ejecución por pasos.
   *
   * Encapsulamos toda la lógica en un único procedimiento que favorece su reutilización, aportando modularidad.
   *
   * Gracias al manejo de excepciones podemos controlar en todo momento lo que pasa durante la ejecución del
   * procedimiento. Nos permite informar sobre cualquier tipo de error que ocurra y modificar la actuación
   * del procedimiento (control) dependiendo de dichos sucesos.
   *
   * Manejamos la transaccionalidad gracias al empleo de commit al final del procedimiento (que se ejecutará si 
   * no ha ocurrido ninǵun problema) aportando atomicidad a las operaciones realizadas. Si embargo si se produce
   * algún error, siempre se ejecutará un rollback para mantener la integridad de la base de datos.
   * También empleamos FOR UPDATE para evitar problemas relacionados con las transacciones concurrentes.
   */


create or replace
procedure reset_seq( p_seq_name varchar )
is
    l_val number;
begin
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/


create or replace procedure inicializa_test is
begin
    
    reset_seq('seq_pedidos');
        
  
    delete from Detalle_pedido;
    delete from Pedidos;
    delete from Platos;
    delete from Personal_servicio;
    delete from Clientes;
    
    -- Insertar datos de prueba
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (1, 'Pepe', 'Perez', '123456789');
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (2, 'Ana', 'Garcia', '987654321');
    
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (1, 'Carlos', 'Lopez', 0);
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (2, 'Maria', 'Fernandez', 5);
    
    insert into Platos (id_plato, nombre, precio, disponible) values (1, 'Sopa', 10.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (2, 'Pasta', 12.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (3, 'Carne', 15.0, 0);

    commit;
end;
/

exec inicializa_test;

-- Completa lost test, incluyendo al menos los del enunciado y añadiendo los que consideres necesarios

create or replace procedure test_registrar_pedido is
begin
  
  --Primero inicializo la base de datos con los valores de prueba para los teses
  begin
    inicializa_test;
  end;
  
  /*
   * En los teses no hacemos rollback dentro del bloque de captura de excepciones
   * ya que si salta una excepción dentro del procedimiento, al capturarlas en
   * su propio bloque para propagarlas, ya se hace un rollback.
   *
   * Sin embargo si que ejecutamos un rollback si el procedimiento ha funcionado
   * correctamente y no debería haberlo hecho, además imprimimos también un mensaje.
   * (el rollback no tendría muchos efectos porque se habría ejecutado el commit del procedimiento)
   * 
   * Se han incluido algunos teses mas para comprobar todos los posibles aspectos de 
   * creación de pedido (platos distintos, platos iguales, y un solo plato) e introducción de 
   * plato inexistente (tanto primer como segundo plato, esta información se puede ver en 
   * el mensaje de SQLERRM).
   *
   * Hemos empleado dbms_output.put_line('Mensaje '||SQLERRM); para mostrar exactamente
   * el código de error junto con el mensaje que manda el procedimiento.
   *
   * Hemos quitado dbms_output.put_line('Error nro '||SQLCODE); ya que había sobrecarga
   * de información a la hora de su lectura y el código de la excepción ya se ve en 
   * SQLERRM.
   *
   * Empleamos CHR(10) para insertar un salto de línea.
   */
  
  -- Caso 1: El pedido se realiza correctamente con dos platos distintos
  begin
    dbms_output.put_line(CHR(10)||'Caso 1.1: Registro de un pedido correcto con dos platos distintos');
    registrar_pedido(1,1,1,2);
    dbms_output.put_line('BIEN: El pedido se realiza correctamente');
  exception   
    when others then
        dbms_output.put_line('MAL: El pedido no se realiza correctamente');
        dbms_output.put_line('Mensaje '||SQLERRM);
  end;
  
  
  -- Caso 1.2: El pedido se realiza correctamente con dos platos iguales
  begin
    dbms_output.put_line(CHR(10)||'Caso 1.2: Registro de un pedido correcto con dos platos iguales');
    registrar_pedido(1,1,2,2);
    dbms_output.put_line('BIEN: El pedido se realiza correctamente');
  exception   
    when others then
        dbms_output.put_line('MAL: El pedido no se realiza correctamente');
        dbms_output.put_line('Mensaje '||SQLERRM);
  end;
  
  
  -- Caso 1.3: El pedido se realiza correctamente con un solo plato
  begin
    dbms_output.put_line(CHR(10)||'Caso 1.3: Registro de un pedido correcto con un solo plato');
    registrar_pedido(2,1,2);
    dbms_output.put_line('BIEN: El pedido se realiza correctamente');
  exception   
    when others then
        dbms_output.put_line('MAL: El pedido no se realiza correctamente');
        dbms_output.put_line('Mensaje '||SQLERRM);
  end;
  

  -- Caso 2: Si se realiza un pedido vacio (sin platos) devuelve el error -20002.
  begin
    dbms_output.put_line(CHR(10)||'Caso 2: Realización de un pedido vacio');
    registrar_pedido( 1, 1, NULL, NULL);    
    dbms_output.put_line('MAL: No da error al realizar un pedido vacio');
    rollback;
  exception
    when others then
      if SQLCODE = -20002 then
        dbms_output.put_line('BIEN: Detecta pedido sin platos.');
        dbms_output.put_line('Mensaje '||SQLERRM);
      else
        dbms_output.put_line('MAL: Da error pero no detecta pedido sin platos.');
        dbms_output.put_line('Mensaje '||SQLERRM);
      end if;
  end; 
  
    
  -- Caso 3.1: Si se realiza un pedido con un plato que no existe devuelve en error -20004.
  begin
    dbms_output.put_line(CHR(10)||'Caso 3.1: Realización de un pedido con el primer plato inexistente');
    registrar_pedido( 2, 1, 4, 2);    
    dbms_output.put_line('MAL: No da error al realizar un pedido con un plato inexistente.');
    rollback;
  exception
    when others then
      if SQLCODE = -20004 then
        dbms_output.put_line('BIEN: Detecta pedido con plato inexistente.');
        dbms_output.put_line('Mensaje '||SQLERRM);
      else
        dbms_output.put_line('MAL: Da error pero no detecta pedido con plato inexistente.');
        dbms_output.put_line('Mensaje '||SQLERRM);
      end if;
  end;
  
  
  -- Caso 3.2: Si se realiza un pedido con un plato que no existe devuelve en error -20004.
  begin
    dbms_output.put_line(CHR(10)||'Caso 3.2: Realización de un pedido con el segundo plato inexistente');
    registrar_pedido( 2, 1, 2, 4);    
    dbms_output.put_line('MAL: No da error al realizar un pedido con un plato inexistente.');
    rollback;
  exception
    when others then
      if SQLCODE = -20004 then
        dbms_output.put_line('BIEN: Detecta pedido con plato inexistente.');
        dbms_output.put_line('Mensaje '||SQLERRM);
      else
        dbms_output.put_line('MAL: Da error pero no detecta pedido con plato inexistente.');
        dbms_output.put_line('Mensaje '||SQLERRM);
      end if;
  end;
  
  
  -- Caso 4: Si se realiza un pedido que incluye un plato que no esta ya disponible devuelve el error -20001.
  begin
    dbms_output.put_line(CHR(10)||'Caso 4: Realización de un pedido con un plato no disponible');
    registrar_pedido( 1, 1, 2, 3);    
    dbms_output.put_line('MAL: No da error al realizar un pedido con un plato no disponible.');
    rollback;
  exception
    when others then
      if SQLCODE = -20001 then
        dbms_output.put_line('BIEN: Detecta pedido con plato no disponible.');
        dbms_output.put_line('Mensaje '||SQLERRM);
      else
        dbms_output.put_line('MAL: Da error pero no detecta pedido con plato no disponible.');
        dbms_output.put_line('Mensaje '||SQLERRM);
      end if;
  end;
  
  
  -- Caso 5: Personal de servicio ya tiene 5 pedidos activos y se le asigna otro pedido devuelve el error -20003
  begin
    dbms_output.put_line(CHR(10)||'Caso 5: Encargo de un pedido a un trabajador que ya tiene 5 pedidos');
    registrar_pedido( 1, 2, 1, 2);    
    dbms_output.put_line('MAL: No da error encargar un pedido a un trabajador que ya tiene 5 pedidos');
    rollback;
  exception
    when others then
      if SQLCODE = -20003 then
        dbms_output.put_line('BIEN: Detecta que el trabajador ya tiene el maximo de pedidos.');
        --dbms_output.put_line('Error nro '||SQLCODE);
        dbms_output.put_line('Mensaje '||SQLERRM);
      else
        dbms_output.put_line('MAL: Da error pero no detecta que el trabajador ya tiene el maximo de pedidos.');
        --dbms_output.put_line('Error nro '||SQLCODE);
        dbms_output.put_line('Mensaje '||SQLERRM);
      end if;
  end;
end;
/


set serveroutput on;
exec test_registrar_pedido;
